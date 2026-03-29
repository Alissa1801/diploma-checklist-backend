require "open3"
require "tempfile"
require "fileutils"

class YoloService
  def initialize(check, direct_path = nil)
    @check = check
    @direct_path = direct_path
  end

  def save_result
    FileUtils.mkdir_p(Rails.root.join("public", "analysis"))

    return nil unless @check.photo.attached? || @direct_path

    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s
    temp_photo = Tempfile.new([ "check_photo", ".jpg" ], binmode: true)

    begin
      # Получение файла: приоритет прямому пути из /tmp (защита от FileNotFoundError)
      if @direct_path && File.exist?(@direct_path)
        FileUtils.cp(@direct_path, temp_photo.path)
        Rails.logger.info "YOLO_READ: Direct path used"
      else
        temp_photo.write(@check.photo.download)
        temp_photo.flush
        Rails.logger.info "YOLO_READ: ActiveStorage download used"
      end

      command = "python3 #{script_path} #{temp_photo.path} #{model_path}"
      stdout, stderr, status = Open3.capture3(command)

      if status.success?
        # Извлекаем JSON из вывода (игнорируем возможные системные логи YOLO)
        json_match = stdout.match(/\{.*\}/m)
        result_data = json_match ? JSON.parse(json_match[0]) : nil

        if result_data && !result_data["error"]
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

          @check.update!(
            status: result_data["is_approved"] ? 2 : 3,
            score: result_data["confidence"]
          )

          Rails.logger.info "YOLO_SUCCESS: Check ##{@check.id} processed"
          analysis
        else
          Rails.logger.error "ML_LOGIC_ERROR: #{result_data&.fetch('error', 'Invalid JSON structure')}"
          nil
        end
      else
        Rails.logger.error "PYTHON_EXECUTION_ERROR: #{stderr}"
        nil
      end

    rescue => e
      Rails.logger.error "YOLO_SERVICE_EXCEPTION: #{e.message}"
      nil
    ensure
      temp_photo.close
      temp_photo.unlink
    end
  end
end
