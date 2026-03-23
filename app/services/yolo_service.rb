class YoloService
  def initialize(check)
    @check = check
  end

  def save_result
    # 1. Пути к файлам
    # Извлекаем путь к оригинальному фото из ActiveStorage
    image_path = ActiveStorage::Blob.service.path_for(@check.photo.key)
    model_path = Rails.root.join("lib", "ml", "best.pt").to_s
    script_path = Rails.root.join("lib", "ml", "predict.py").to_s

    # 2. Запуск Python-скрипта
    # Передаем два аргумента: путь к фото и путь к модели
    python_output = `python3 #{script_path} #{image_path} #{model_path}`

    # Парсим JSON, который вернул Python
    result_data = JSON.parse(python_output) rescue nil

    if result_data && !result_data["error"]
      # 3. Сохраняем в базу данных AnalysisResult
      analysis = AnalysisResult.create!(
        check: @check,
        is_approved: result_data["is_approved"],
        confidence_score: result_data["confidence"],
        detected_objects: result_data["objects"], # Массив хешей [{name: 'pillow', count: 2}]
        issues: result_data["issues"],           # Массив строк ['pillow_messy']
        feedback: result_data["feedback"],
        ml_model_version: "yolov8_hotel_v1.0"
      )

      # 4. Обновляем статус самого чека (как было в симуляции)
      # 2 - approved, 3 - rejected
      @check.update!(
        status: result_data["is_approved"] ? 2 : 3,
        score: result_data["confidence"]
      )

      analysis
    else
      Rails.logger.error "YOLO_ERROR: #{python_output}"
      nil
    end
  end
end
