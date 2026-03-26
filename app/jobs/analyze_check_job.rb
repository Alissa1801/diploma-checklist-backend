class AnalyzeCheckJob < ApplicationJob
  queue_as :default

  def perform(check_id)
    check = Check.find_by(id: check_id)
    return unless check

    Rails.logger.info "ML_START: Начинаем анализ в фоновом Job для чека ##{check.id}"

    begin
      service = YoloService.new(check)
      service.save_result
      Rails.logger.info "ML_FINISH: Анализ успешно завершен для чека ##{check.id}"
    rescue => e
      Rails.logger.error "ML_JOB_ERROR: #{e.message}"
      check.update(status: 0) # Статус "Ошибка"
    end
  end
end
