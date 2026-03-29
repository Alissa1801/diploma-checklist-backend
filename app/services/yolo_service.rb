require "open3"
require "tempfile"
require "fileutils"

class YoloService
  # Добавляем аргумент direct_path, чтобы брать файл из /tmp до его перемещения ActiveStorage
  def initialize(check, direct_path = nil)
    @check = check
    @direct_path = direct_path
  end

  def save_result
    # Создаем папку для результатов, если её нет
    FileUtils.mkdir_p(Rails.root.join("public", "analysis"))

    # 1. Подготовка путей
    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s

    # Создаем временный файл для работы нейросети
    temp_photo = Tempfile.new([ "check_photo", ".jpg" ], binmode: true)

    begin
      # ЛОГИКА ДОСТУПА К ФАЙЛУ:
      # ЕСЛИ У НАС ЕСТЬ ПРЯМОЙ ПУТЬ (из контроллера), берем его — это спасает от FileNotFoundError
      if @direct_path && File.exist?(@direct_path)
        FileUtils.cp(@direct_path, temp_photo.path)
        Rails.logger.info "YOLO_DIRECT_READ: Взяли файл напрямую из /tmp контроллера"
      elsif @check.photo.attached?
        # Иначе пытаемся скачать через ActiveStorage (запасной вариант)
        temp_photo.write(@check.photo.download)
        temp_photo.flush
        Rails.logger.info "YOLO_BLOB_READ: Файл загружен через ActiveStorage"
      else
        raise "No photo available for analysis"
      end

      # 2. Запуск Python-скрипта
      command = "python3 #{script_path} #{temp_photo.path} #{model_path}"
      stdout, stderr, status = Open3.capture3(command)

      # 3. Обработка результата
      if status.success?
        # Очищаем stdout от лишних пробелов и парсим JSON
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
          # 2 - approved (Одобрено), 3 - rejected (Отклонено)
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
        # Ошибка выполнения Python (например, нехватка памяти в Railway)
        Rails.logger.error "PYTHON_EXECUTION_ERROR: #{stderr}"
        nil
      end

    rescue => e
      Rails.logger.error "YOLO_SERVICE_EXCEPTION: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      nil
    ensure
      # Очистка временного файла
      temp_photo.close
      temp_photo.unlink
    end
  end
end
