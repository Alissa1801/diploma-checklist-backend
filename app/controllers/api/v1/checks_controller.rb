module Api
  module V1
    class ChecksController < ApplicationController
      before_action :log_api_request, only: [:create, :index, :show]
      
      # Разрешенные форматы для iPhone камеры
      ALLOWED_IMAGE_TYPES = [
        'image/jpeg',      # JPEG
        'image/jpg',       # JPG 
        'image/png',       # PNG
        'image/heic',      # HEIC (iPhone)
        'image/heif'       # HEIF (iPhone)
      ].freeze
      
      MAX_FILE_SIZE = 5.megabytes
      
      def index
        checks = current_user.checks.includes(:zone, :analysis_result).order(created_at: :desc)
        
        LoggingService.log_user_action(current_user, 'get_checks_list', { count: checks.count })
        
        render json: checks, include: [:zone, :analysis_result]
      end
      
      def show
        check = current_user.checks.find(params[:id])
        
        render json: check, include: [:zone, :analysis_result, photo_attachment: { blob: :variant_records }]
      rescue ActiveRecord::RecordNotFound => e
        LoggingService.log_error(e, { check_id: params[:id], user_id: current_user.id })
        render json: { error: 'Check not found' }, status: :not_found
      end
      
      def create
        ActiveRecord::Base.transaction do
          check = current_user.checks.new(check_params)
          
          # Устанавливаем дефолтный статус
          check.status = 0 # pending
          check.submitted_at ||= Time.current
          
          if check.save
            # Обрабатываем одно фото
            process_single_photo(check)
            
            # Проверяем, что фото прикрепилось
            if check.photo.attached?
              # Логируем создание
              LoggingService.log_user_action(current_user, 'create_check', {
                check_id: check.id,
                zone_id: check.zone_id,
                photo_type: check.photo.blob.content_type,
                photo_size: check.photo.blob.byte_size
              })

              render json: {
                success: true,
                check: {
                  id: check.id,
                  zone_id: check.zone_id,
                  user_id: check.user_id,
                  status: check.status,
                  status_text: check.status_text,
                  submitted_at: check.submitted_at,
                  created_at: check.created_at
                },
                message: 'Check created successfully with photo'
              }, status: :created
            else
              # Если фото не прикрепилось, откатываем
              raise ActiveRecord::Rollback, "Photo is required"
            end
          else
            LoggingService.log_error(
              StandardError.new("Check validation failed: #{check.errors.full_messages.join(', ')}"),
              { params: params, errors: check.errors.full_messages }
            )
            
            render json: { 
              success: false, 
              errors: check.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
      rescue ActiveRecord::Rollback => e
        render json: { 
          success: false, 
          error: 'Photo is required for check creation' 
        }, status: :unprocessable_entity
      rescue => e
        LoggingService.log_error(e, { 
          params: params.except(:photo),
          user_id: current_user.id 
        })
        
        render json: { 
          success: false, 
          error: e.message 
        }, status: :unprocessable_entity
      end
      
      private
      
      def check_params
        params.permit(:zone_id, :room_number, :submitted_at)
      end
      
      def process_single_photo(check)в
        # Получаем фото из параметра :photo
        photo = params[:photo]
        
        raise "No photo provided" unless photo.present?
        
        if photo.respond_to?(:tempfile)
          # Uploaded file через multipart/form-data
          process_uploaded_file(check, photo)
        elsif photo.is_a?(String) && photo.start_with?('data:image')
          # Data URL (base64)
          process_data_url_photo(check, photo)
        else
          raise "Invalid photo format. Expected uploaded file or data URL"
        end
      end
      
      def process_uploaded_file(check, uploaded_file)
        # Проверяем тип файла
        unless valid_image_type?(uploaded_file.content_type)
          raise "Invalid photo format. Allowed: #{ALLOWED_IMAGE_TYPES.join(', ')}"
        end
        
        # Проверяем размер
        if uploaded_file.size > MAX_FILE_SIZE
          raise "Photo is too large. Maximum size is #{MAX_FILE_SIZE / 1.megabyte}MB"
        end
        
        # Удаляем старое фото, если есть
        check.photo.purge if check.photo.attached?
        
        # Генерируем имя файла
        filename = generate_filename(check, uploaded_file)
        
        # Прикрепляем фото
        check.photo.attach(
          io: uploaded_file,
          filename: filename,
          content_type: uploaded_file.content_type
        )
      end
      
      def process_data_url_photo(check, data_url)
        # Парсим data URL
        matches = data_url.match(/^data:(image\/[^;]+);base64,(.*)$/)
        
        unless matches
          raise "Invalid data URL format. Expected: data:image/[type];base64,[data]"
        end
        
        content_type = matches[1]
        base64_data = matches[2]
        
        # Проверяем тип
        unless valid_image_type?(content_type)
          raise "Invalid photo format. Allowed: #{ALLOWED_IMAGE_TYPES.join(', ')}"
        end
        
        # Декодируем base64
        decoded_data = Base64.decode64(base64_data)
        
        # Проверяем размер
        if decoded_data.bytesize > MAX_FILE_SIZE
          raise "Photo is too large. Maximum size is #{MAX_FILE_SIZE / 1.megabyte}MB"
        end
        
        # Создаем временный файл
        tempfile = create_tempfile(decoded_data, content_type)
        
        # Удаляем старое фото
        check.photo.purge if check.photo.attached?
        
        # Генерируем имя файла
        filename = generate_filename(check, nil, content_type)
        
        # Прикрепляем файл
        check.photo.attach(
          io: tempfile,
          filename: filename,
          content_type: content_type
        )
        
      ensure
        tempfile&.close
        tempfile&.unlink if tempfile
      end
      
      def create_tempfile(data, content_type)
        extension = get_extension_for_content_type(content_type)
        tempfile = Tempfile.new(["check_photo", extension], binmode: true)
        tempfile.write(data)
        tempfile.rewind
        tempfile
      end
      
      def get_extension_for_content_type(content_type)
        case content_type.downcase
        when 'image/jpeg', 'image/jpg'
          '.jpg'
        when 'image/png'
          '.png'
        when 'image/heic', 'image/heif'
          '.heic'
        else
          '.jpg'
        end
      end
      
      def generate_filename(check, uploaded_file = nil, content_type = nil)
        timestamp = Time.now.to_i
        zone_id = check.zone_id
        
        if uploaded_file
          original_name = uploaded_file.original_filename
          extension = File.extname(original_name).presence || get_extension_for_content_type(uploaded_file.content_type)
        elsif content_type
          extension = get_extension_for_content_type(content_type)
        else
          extension = '.jpg'
        end
        
        # Формат: check_[id]_zone_[zone]_[timestamp].[ext]
        "check_#{check.id}_zone_#{zone_id}_#{timestamp}#{extension}"
      end
      
      def valid_image_type?(content_type)
        ALLOWED_IMAGE_TYPES.include?(content_type.downcase)
      end

      def serialize_check(check)
        {
          id: check.id,
          zone_id: check.zone_id,
          user_id: check.user_id,
          status: check.status,
          status_text: check.status_text,
          submitted_at: check.submitted_at,
          created_at: check.created_at,
          updated_at: check.updated_at,  # ← ДОБАВЬ
          score: check.score,  
          photo: serialize_photo(check.photo),
          zone: check.zone
        }
      end


     #def serialize_photo(photo)
      #  return nil unless photo&.attached?

     #   {
      #    id: photo.id,
       #   url: rails_blob_url(photo, only_path: false),
        #  content_type: photo.blob.content_type,
         # filename: photo.blob.filename.to_s,
        #  byte_size: photo.blob.byte_size,
         # created_at: photo.created_at,
        #  updated_at: photo.updated_at
      #  }
    #  end
      
      def log_api_request
        LoggingService.log_api_request(request, response, current_user)
      end
    end
  end
end