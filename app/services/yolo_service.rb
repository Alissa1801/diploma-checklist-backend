require "open3"
require "tempfile"
require "fileutils"

class YoloService
  def initialize(check, direct_path = nil)
    @check = check
    @direct_path = direct_path
  end

  def save_result
    # 1. Подготовка папок и путей
    FileUtils.mkdir_p(Rails.root.join("public", "analysis"))

    return nil unless @check.photo.attached? || @direct_path

    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s
    temp_photo = Tempfile.new([ "check_photo_#{@check.id}_", ".jpg" ], binmode: true)

    begin
      # 2. Копирование фото во временный файл для Python
      if @direct_path && File.exist?(@direct_path)
        FileUtils.cp(@direct_path, temp_photo.path)
      else
        temp_photo.write(@check.photo.download)
        temp_photo.flush
      end

      # 3. Запуск анализа
      # Вызываем напрямую, так как библиотеки теперь установлены глобально в системе
      command = "python3 #{script_path} #{temp_photo.path} #{model_path} 2>&1"

      Rails.logger.info "ML_EXECUTION: Starting analysis for Check ##{@check.id}"
      
      # Запускаем Python. Open3 захватит весь вывод (stdout + stderr)
      stdout, stderr, status = Open3.capture3(command)

      if status.success?
        # Ищем JSON-блок в выводе
        json_match = stdout.match(/(\{.*\})/m)

        if json_match
          begin
            result_data = JSON.parse(json_match[1])

            if result_data["error"]
              Rails.logger.error "ML_PYTHON_LOGIC_ERROR: #{result_data['error']}"
              return nil
            end

            # 4. Сохранение результата в базу
            AnalysisResult.transaction do
              analysis = AnalysisResult.create!(
                check: @check,
                is_approved: result_data["is_approved"],
                confidence_score: result_data["confidence"],
                detected_objects: result_data["objects"],
                issues: result_data["issues"],
                feedback: result_data["feedback"],
                #processed_url: result_data["processed_url"],
                ml_model_version: "yolov8_hotel_v1.0"
              )

              # Обновляем статус: 2 - Одобрено, 3 - Отклонено
              @check.update!(
                status: result_data["is_approved"] ? 2 : 3,
                score: result_data["confidence"]
              )

              Rails.logger.info "YOLO_SUCCESS: Check ##{@check.id} processed"
              analysis
            end
          rescue JSON::ParserError => e
            Rails.logger.error "ML_JSON_PARSE_ERROR: Failed to parse Python output. Raw: #{stdout}"
            nil
          end
        else
          Rails.logger.error "ML_OUTPUT_ERROR: Python executed but no JSON found. Output: #{stdout}"
          nil
        end
      else
        Rails.logger.error "PYTHON_EXECUTION_ERROR: Status #{status.exitstatus}. Output: #{stdout}"
        nil
      end
    rescue => e
      Rails.logger.error "YOLO_SERVICE_EXCEPTION: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      nil
    ensure
      if temp_photo
        temp_photo.close
        temp_photo.unlink
      end
    end
  end
end