require "open3"
require "tempfile"
require "fileutils"

class YoloService
  def initialize(check)
    @check = check
  end

  def save_result
    # Создаем папку для результатов, если её нет
    FileUtils.mkdir_p(Rails.root.join("public", "analysis"))

    # Проверяем наличие фото
    return nil unless @check.photo.attached?

    # 1. Подготовка путей
    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s

    # Создаем временный файл
    temp_photo = Tempfile.new([ "check_photo", ".jpg" ], binmode: true)

    begin
      # Пытаемся получить файл максимально надежным способом
      blob = @check.photo.blob

      begin
        # Способ А: Прямое копирование с диска (самый быстрый и обходит IntegrityError)
        storage_path = ActiveStorage::Blob.service.path_for(blob.key)
        FileUtils.cp(storage_path, temp_photo.path)
        Rails.logger.info "YOLO_DISK_READ: Файл скопирован напрямую из хранилища"
      rescue => e
        # Способ Б: Стандартный download (если Способ А не сработал или сервис не Disk)
        temp_photo.write(@check.photo.download)
        temp_photo.flush
        Rails.logger.info "YOLO_BLOB_DOWNLOAD: Файл загружен через ActiveStorage download"
      end

      # 2. Запуск Python-скрипта
      # Используем полные пути и захватываем stdout/stderr
      command = "python3 #{script_path} #{temp_photo.path} #{model_path}"
      stdout, stderr, status = Open3.capture3(command)

      # 3. Обработка результата
      if status.success?
        # Очищаем stdout от возможных лишних пробелов и парсим JSON
        result_data = JSON.parse(stdout.strip) rescue nil

        if result_data && !result_data["error"]
          # 4. Сохранение в базу данных AnalysisResult
          analysis = AnalysisResult.create!(
            check: @check,
            is_approved: result_data["is_approved"],
            confidence_score: result_data["confidence"],
            detected_objects: result_data["objects"],
            issues: result_data["issues"],
            feedback: result_data["feedback"],
            processed_url: result_data["processed_url"],
            ml_model_version: "yolov8_hotel_v1.0"
          )

          # 5. Обновление статуса основной проверки
          # 2 - approved, 3 - rejected
          @check.update!(
            status: result_data["is_approved"] ? 2 : 3,
            score: result_data["confidence"]
          )

          analysis
        else
          error_msg = result_data ? result_data["error"] : "Не удалось распарсить JSON из Python"
          Rails.logger.error "ML_LOGIC_ERROR: #{error_msg}"
          nil
        end
      else
        # Если Python упал с системной ошибкой (например, не хватило памяти)
        Rails.logger.error "PYTHON_EXECUTION_ERROR: #{stderr}"
        nil
      end

    rescue => e
      Rails.logger.error "YOLO_SERVICE_EXCEPTION: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      nil
    ensure
      # Обязательная очистка
      temp_photo.close
      temp_photo.unlink
    end
  end
end
