require "open3"
require "tempfile"

class YoloService
  def initialize(check)
    @check = check
  end

  def save_result
    # Проверяем, прикреплено ли фото, чтобы не упасть с ошибкой
    return nil unless @check.photo.attached?

    # 1. Подготовка путей
    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s

    # Создаем временный файл для фото.
    # Это нужно, так как Python не может прочитать файл напрямую из облака или базы ActiveStorage.
    temp_photo = Tempfile.new([ "check_photo", ".jpg" ])

    begin
      # Скачиваем содержимое фото во временный файл
      temp_photo.binmode
      temp_photo.write(@check.photo.download)
      temp_photo.flush

      # 2. Запуск Python-скрипта через Open3.
      # Это позволяет нам отделить чистый JSON (stdout) от возможных системных предупреждений (stderr).
      command = "python3 #{script_path} #{temp_photo.path} #{model_path}"
      stdout, stderr, status = Open3.capture3(command)

      # 3. Парсинг результата
      if status.success?
        result_data = JSON.parse(stdout) rescue nil

        if result_data && !result_data["error"]
          # 4. Сохранение в базу данных AnalysisResult
          analysis = AnalysisResult.create!(
            check: @check,
            is_approved: result_data["is_approved"],
            confidence_score: result_data["confidence"],
            detected_objects: result_data["objects"],
            issues: result_data["issues"],
            # Мы убрали feedback, так как в модели его нет,
            # либо добавь его в модель через миграцию
            processed_url: result_data["processed_url"],
            ml_model_version: "yolov8_hotel_v1.0"
          )

          # 5. Обновление статуса основной проверки (Check)
          # 2 - approved (Одобрено), 3 - rejected (Отклонено)
          @check.update!(
            status: result_data["is_approved"] ? 2 : 3,
            score: result_data["confidence"]
          )

          analysis
        else
          Rails.logger.error "ML_LOGIC_ERROR: #{result_data&.fetch('error', 'Unknown error')}"
          nil
        end
      else
        # Если Python упал с системной ошибкой
        Rails.logger.error "PYTHON_EXECUTION_ERROR: #{stderr}"
        nil
      end

    rescue => e
      Rails.logger.error "YOLO_SERVICE_EXCEPTION: #{e.message}"
      nil
    ensure
      # Обязательно закрываем и удаляем временный файл, чтобы не забивать память сервера
      temp_photo.close
      temp_photo.unlink
    end
  end
end
