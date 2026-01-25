module Api
  module V1
    class AnalysisController < ApplicationController
      before_action :log_api_request
      
      def show
        check = current_user.checks.find(params[:check_id])
        analysis_result = check.analysis_result
        
        if analysis_result
          # Логируем запрос результата анализа
          LoggingService.log_user_action(current_user, 'get_analysis_result', {
            check_id: check.id,
            approved: analysis_result.approved?,
            confidence_score: analysis_result.confidence_score
          })
          
          render json: analysis_result
        else
          render json: { 
            success: false, 
            message: 'Analysis not found or not yet processed' 
          }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Check not found' }, status: :not_found
      end
      
      def analyze
        check = current_user.checks.find(params[:check_id])
        
        # Проверяем, не анализировалась ли уже
        if check.analysis_result.present?
          return render json: { 
            success: false, 
            message: 'Analysis already performed' 
          }, status: :bad_request
        end
        
        start_time = Time.current
        
        # Запускаем анализ через нейросеть
        result = analyze_with_ml(check)
        
        processing_time = Time.current - start_time
        
        # Создаем запись с результатом анализа
        analysis_result = AnalysisResult.create!(
          check: check,
          confidence_score: result[:confidence_score],
          is_approved: result[:is_approved],
          detected_objects: result[:detected_objects],
          issues: result[:issues],
          feedback: result[:feedback],
          ml_model_version: result[:ml_model_version]
        )
        
        # Обновляем статус проверки
        check.update(
          status: result[:is_approved] ? 2 : 3,
          score: result[:confidence_score]
        )
        
        # Логируем анализ
        LoggingService.log_user_action(current_user, 'manual_analysis_trigger', {
          check_id: check.id,
          processing_time: processing_time,
          approved: result[:is_approved]
        })
        
        # Логируем работу нейросети
        LoggingService.log_ml_analysis(check, result, processing_time)
        
        render json: {
          success: true,
          analysis: analysis_result,
          processing_time: processing_time.round(2)
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Check not found' }, status: :not_found
      rescue => e
        LoggingService.log_error(e, { check_id: params[:check_id], user_id: current_user.id })
        render json: { 
          success: false, 
          error: 'Failed to analyze check' 
        }, status: :internal_server_error
      end
      
      private
      
      def analyze_with_ml(check)
        # Эмуляция работы нейросети
        sleep(rand(0.5..2.0)) # Имитация обработки
        
        {
          ml_model_version: "1.0.0",
          confidence_score: rand(85..99),
          is_approved: rand(0..1) == 1,
          detected_objects: [
            { name: 'pillow', count: 2, confidence: 0.95 },
            { name: 'bed', count: 1, confidence: 0.98 }
          ],
          issues: rand(0..1) == 1 ? ['wrinkled_bedspread'] : [],
          feedback: "Кровать убрана #{rand(0..1) == 1 ? 'отлично' : 'удовлетворительно'}"
        }
      end
      
      def log_api_request
        LoggingService.log_api_request(request, response, current_user)
      end
    end
  end
end
