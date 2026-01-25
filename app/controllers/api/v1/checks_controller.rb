module Api::V1
  class ChecksController < ApplicationController
    def create
      zone = Zone.find(params[:zone_id])
      
      check = current_user.checks.new(
        zone: zone,
        status: 0,
        submitted_at: Time.current
      )
      
      # Прикрепляем фото
      if params[:photo].present?
        puts "Прикрепляем файл: #{params[:photo].original_filename}"
        check.photos.attach(params[:photo])
      end
      
      if check.save
        # ВАЖНО: перезагружаем чек после сохранения
        check.reload
        
        render json: {
          success: true,
          check: {
            id: check.id,
            zone_id: check.zone_id,
            status: check.status,
            status_text: check.status_text,
            submitted_at: check.submitted_at,
            zone_name: zone.name,
            photo_count: check.photos.count,  # Теперь правильно
            photo_urls: check.photos.map { |p| rails_blob_url(p) }
          },
          message: 'Чек-лист создан успешно!'
        }
      else
        render json: {
          success: false,
          errors: check.errors.full_messages
        }
      end
    end
  end
end
