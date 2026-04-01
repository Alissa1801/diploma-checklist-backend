module Api
  module V1
    class ChecksController < ApplicationController

      skip_before_action :authenticate_user!, only: [:debug_ml, :clear_db], raise: false
      before_action :log_api_request, only: [ :create, :index, :show ]

      ALLOWED_IMAGE_TYPES = [
        "image/jpeg", "image/jpg", "image/png", "image/heic", "image/heif"
      ].freeze

      MAX_FILE_SIZE = 5.megabytes

def index
  # 1. Загружаем данные с оптимизацией (чтобы не было 100500 запросов к БД)
  checks = current_user.admin? ? Check.all : current_user.checks
  @checks = checks.includes(:zone, :analysis_result, :user).order(created_at: :desc)

  # 2. Рендерим через сериализатор. 
  # base_url нужен твоему AnalysisResultSerializer, чтобы собрать полную ссылку на фото
  render json: @checks, 
         each_serializer: CheckSerializer, 
         base_url: "https://diploma-checklist-backend-production.up.railway.app"
end

def show
  @check = current_user.admin? ? Check.find(params[:id]) : current_user.checks.find(params[:id])
  
  render json: @check, 
         serializer: CheckSerializer, 
         base_url: "https://diploma-checklist-backend-production.up.railway.app"
end

      def create
        check = current_user.checks.new(check_params)
        check.status = 1
        check.submitted_at ||= Time.current

        # ВЫХВАТЫВАЕМ ПУТЬ К ТЕМП-ФАЙЛУ СРАЗУ
        raw_photo_path = params[:photo]&.tempfile&.path

        if check.save
          begin
            process_single_photo(check)
          rescue => e
            Rails.logger.warn "ATTACH_ERROR_IGNORED: #{e.message}"
          end

          # ПЕРЕДАЕМ ПУТЬ В СЕРВИС
          begin
            Rails.logger.info "ML_START: Начинаем анализ ##{check.id}"
            # Передаем и чек, и путь к файлу, который только что пришел
            service = YoloService.new(check, raw_photo_path)
            service.save_result
            check.reload

            render_check_json(check, :created)
          rescue => e
            Rails.logger.error "ML_CRITICAL_ERROR: #{e.message}"
            render json: { error: e.message }, status: :unprocessable_entity
          end
        else
          render json: { errors: check.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def debug_ml
        # Запускаем скрипт отладки и возвращаем текст
        stdout, stderr, status = Open3.capture3("python3 debug_env.py 2>&1")
        render plain: "STDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}\nSTATUS: #{status.exitstatus}"
      end

      def clear_db
        Check.destroy_all
        render json: { status: "Database cleared!" }
      end

      private

      def render_check_json(check, status)
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

        render json: check_data, adapter: false, status: status
      end

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
