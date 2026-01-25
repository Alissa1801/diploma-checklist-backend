class MlSimulationService
  def initialize(check)
    @check = check
  end
  
  def analyze
    # Эмуляция анализа нейросети
    # Для кровати проверяем: подушки, покрывало, посторонние предметы
    
    zone_config = @check.zone
    
    # Симулируем работу нейросети
    sleep(rand(1..3))  # Имитация обработки
    
    # Случайный результат (в реальности здесь была бы нейросеть)
    is_approved = rand > 0.3  # 70% шанс одобрения
    
    # Определяем проблемы если отклонено
    issues = []
    feedback = ""
    
    if is_approved
      confidence = rand(85..99)
      feedback = "✅ Кровать убрана отлично! Подушки на месте, покрывало ровное."
    else
      confidence = rand(50..84)
      
      # Случайные проблемы
      possible_issues = [
        "Недостаточно подушек (найдено: #{rand(1..2)} из 2)",
        "Покрывало имеет заломы и складки",
        "Обнаружены посторонние предметы на кровати",
        "Подушки расположены неправильно",
        "Углы покрывала не заправлены"
      ]
      
      issues = possible_issues.sample(rand(1..3))
      feedback = "⚠️ Требуется улучшение: #{issues.join(', ')}"
    end
    
    # "Обнаруженные" объекты
    detected_objects = [
      { name: "подушка", count: rand(1..3), confidence: rand(80..95) },
      { name: "одеяло", count: 1, confidence: rand(85..98) },
      { name: "простынь", count: 1, confidence: rand(75..90) }
    ]
    
    {
      is_approved: is_approved,
      confidence_score: confidence,
      detected_objects: detected_objects,
      issues: issues,
      feedback: feedback,
      ml_model_version: "bed_check_v1.0"
    }
  end
  
  def save_result
    result_data = analyze
    
    AnalysisResult.create!(
      check: @check,
      is_approved: result_data[:is_approved],
      confidence_score: result_data[:confidence_score],
      detected_objects: result_data[:detected_objects],
      issues: result_data[:issues],
      feedback: result_data[:feedback],
      ml_model_version: result_data[:ml_model_version]
    )
    
    # Обновляем статус чека
    if result_data[:is_approved]
      @check.update!(status: 2, score: result_data[:confidence_score]) # approved
    else
      @check.update!(status: 3, score: result_data[:confidence_score]) # rejected
    end
    
    result_data
  end
end
