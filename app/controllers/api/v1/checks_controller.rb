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
        checks = @checks.includes(:zone, :analysis_result, :user).order(created_at: :desc)

        LoggingService.log_user_action(current_user, "get_checks_list", {
          count: checks.count,
          is_admin: current_user.admin?
        })

        # Используем adapter: false, чтобы Swift получил данные напрямую
        render json: checks.as_json(
          include: {
            zone: { only: [ :id, :name, :description ] },
            analysis_result: {}
          },
          methods: [ :user_name, :status_text ]
        ).map { |c| c.merge(zone_id: c["zone_id"], submitted_at: c["submitted_at"]) }, adapter: false
      end

      def show
        check = current_user.admin? ? Check.find(params[:id]) : current_user.checks.find(params[:id])

        render json: check.as_json(
          include: {
            zone: { only: [ :id, :name, :description ] },
            analysis_result: {}
          },
          methods: [ :user_name, :status_text ]
        ).merge(zone_id: check.zone_id, submitted_at: check.submitted_at), adapter: false
      rescue ActiveRecord::RecordNotFound => e
        LoggingService.log_error(e, { check_id: params[:id], user_id: current_user.id })
        render json: { error: "Check not found" }, status: :not_found
      end

def create
        check = current_user.checks.new(check_params)
        check.status = 1
        check.submitted_at ||= Time.current

        if check.save
          begin
            process_single_photo(check)

            if check.photo.attached?
              # ФОНОВЫЙ ПОТОК С ЛОГИРОВАНИЕМ
              Thread.new do
                Rails.application.executor.wrap do
                  begin
                    Rails.logger.info "ML_START: Начинаем анализ для чека ##{check.id}"
                    service = YoloService.new(check)
                    service.save_result
                    Rails.logger.info "ML_FINISH: Анализ завершен для чека ##{check.id}"
                  rescue => e
                    Rails.logger.error "ML_THREAD_ERROR: #{e.message}"
                    # В случае фатальной ошибки ML возвращаем статус "Ошибка" (0)
                    check.update(status: 0)
                  end
                end
              end

              # ПОДГОТОВКА ДАННЫХ (Явное формирование хэша)
              check_data = check.as_json(
                include: {
                  zone: { only: [ :id, :name, :description ] },
                  analysis_result: { only: [ :id, :is_approved, :confidence_score, :processed_url, :issues, :feedback ] }
                },
                methods: [ :status_text, :user_name ]
              ).merge({
                "zone_id" => check.zone_id,
                "submitted_at" => check.submitted_at,
                "created_at" => check.created_at
              })

              # ОТВЕТ КЛИЕНТУ (adapter: false отключает сломанные сериализаторы)
              render json: check_data, adapter: false, status: :created

            else
              # Если фото не прикрепилось по какой-то причине
              check.destroy
              render json: { error: "Photo attachment failed" }, status: :unprocessable_entity
            end

          rescue ActiveStorage::IntegrityError => e
            # Ошибка контрольной суммы (часто бывает на Railway), игнорируем и отдаем чек
            Rails.logger.error "INTEGRITY_IGNORE: #{e.message}"

            check_data_fallback = check.as_json(
              include: { zone: { only: [ :id, :name, :description ] } },
              methods: [ :status_text, :user_name ]
            ).merge({
              "zone_id" => check.zone_id,
              "submitted_at" => check.submitted_at
            })

            render json: check_data_fallback, adapter: false, status: :created

          rescue => e
            Rails.logger.error "CREATE_CHECK_ERROR: #{e.message}"
            render json: { error: e.message }, status: :unprocessable_entity
          end
        else
          # Ошибки валидации модели
          render json: { errors: check.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

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
