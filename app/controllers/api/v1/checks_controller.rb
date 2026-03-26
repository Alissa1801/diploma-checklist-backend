module Api
  module V1
    class ChecksController < ApplicationController
      before_action :log_api_request, only: [ :create, :index, :show ]

      ALLOWED_IMAGE_TYPES = [
        "image/jpeg", "image/jpg", "image/png", "image/heic", "image/heif"
      ].freeze

      MAX_FILE_SIZE = 5.megabytes

      def index
        @checks = current_user.admin? ? Check.all : current_user.checks

        # Подгружаем зависимости, чтобы избежать N+1 запросов
        checks = @checks.includes(:zone, :analysis_result, :user).order(created_at: :desc)

        LoggingService.log_user_action(current_user, "get_checks_list", {
          count: checks.count,
          is_admin: current_user.admin?
        })

        # Рендерим со всеми вложенными данными для iOS
        render json: checks,
               include: [ :zone, :analysis_result ],
               methods: [ :user_name, :status_text ]
      end

      def show
        check = current_user.admin? ? Check.find(params[:id]) : current_user.checks.find(params[:id])

        render json: check,
               include: [ :zone, :analysis_result ],
               methods: [ :user_name, :status_text ]
      rescue ActiveRecord::RecordNotFound => e
        LoggingService.log_error(e, { check_id: params[:id], user_id: current_user.id })
        render json: { error: "Check not found" }, status: :not_found
      end

      def create
        # 1. Создаем запись. Важно: check_params теперь разрешает :zone_id
        check = current_user.checks.new(check_params)

        # Устанавливаем статус 1 (processing / в обработке)
        check.status = 1
        check.submitted_at ||= Time.current

        if check.save
          begin
            # 2. Сохраняем фото в ActiveStorage
            process_single_photo(check)

            if check.photo.attached?
              # 3. ФОНОВЫЙ ПОТОК (Thread)
              Thread.new do
                Rails.application.executor.wrap do
                  begin
                    service = YoloService.new(check)
                    service.save_result
                  rescue => e
                    Rails.logger.error "ML_THREAD_ERROR: #{e.message}"
                    check.update(status: 0)
                  end
                end
              end

              # 4. ОТВЕТ КЛИЕНТУ
              render json: check.as_json(
  include: {
    zone: { only: [ :id, :name, :description ] },
    analysis_result: {}
  },
  methods: [ :status_text, :user_name ]
).merge(zone_id: check.zone_id), status: :created

            else
              # Если фото не прикрепилось
              check.destroy
              render json: { success: false, error: "Photo attachment failed" }, status: :unprocessable_entity
            end

          rescue ActiveStorage::IntegrityError

            render json: check.as_json(
              include: { zone: { only: [ :id, :name ] } },
              methods: [ :status_text, :user_name ]
            ), status: :created

          rescue => e
            render json: { error: e.message }, status: :unprocessable_entity
          end
        else
          # Ошибки валидации (например, пустой zone_id)
          render json: { errors: check.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # ОБНОВЛЕННЫЙ МЕТОД PARAMS (Исправляет "Неизвестную зону")
      def check_params
        params.permit(:zone_id, :room_number, :submitted_at, :photo)
      end

      def process_single_photo(check)
        photo = params[:photo]
        raise "No photo provided" unless photo.present?

        if photo.respond_to?(:tempfile)
          process_uploaded_file(check, photo)
        elsif photo.is_a?(String) && photo.start_with?("data:image")
          process_data_url_photo(check, photo)
        else
          # Поддержка прямого прикрепления, если пришел бинарный поток
          check.photo.attach(io: photo, filename: "photo_#{Time.now.to_i}.jpg")
        end
      end

      def process_uploaded_file(check, uploaded_file)
        unless valid_image_type?(uploaded_file.content_type)
          raise "Invalid photo format. Allowed: #{ALLOWED_IMAGE_TYPES.join(', ')}"
        end

        if uploaded_file.size > MAX_FILE_SIZE
          raise "Photo is too large (max 5MB)"
        end

        check.photo.attach(
          io: uploaded_file,
          filename: generate_filename(check, uploaded_file),
          content_type: uploaded_file.content_type
        )
      end

      def process_data_url_photo(check, data_url)
        matches = data_url.match(/^data:(image\/[^;]+);base64,(.*)$/)
        raise "Invalid data URL" unless matches

        content_type = matches[1]
        decoded_data = Base64.decode64(matches[2])

        tempfile = Tempfile.new([ "check_photo", ".jpg" ], binmode: true)
        tempfile.write(decoded_data)
        tempfile.rewind

        check.photo.attach(
          io: tempfile,
          filename: "camera_photo_#{Time.now.to_i}.jpg",
          content_type: content_type
        )
      ensure
        tempfile&.close
        tempfile&.unlink
      end

      def generate_filename(check, uploaded_file)
        ext = File.extname(uploaded_file.original_filename).presence || ".jpg"
        "check_#{check.id}_zone_#{check.zone_id}_#{Time.now.to_i}#{ext}"
      end

      def valid_image_type?(content_type)
        ALLOWED_IMAGE_TYPES.include?(content_type.downcase)
      end

      def log_api_request
        LoggingService.log_api_request(request, response, current_user)
      end
    end
  end
end
