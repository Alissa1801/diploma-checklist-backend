module Api
  module V1
    class AnalysisController < ApplicationController
      before_action :log_api_request

      def show
        check = current_user.checks.find(params[:check_id])
        analysis_result = check.analysis_result

        if analysis_result
          # Логируем
          LoggingService.log_user_action(current_user, "get_analysis_result", {
            check_id: check.id,
            approved: analysis_result.approved?,
            confidence_score: analysis_result.confidence_score
          })

          # ИСПРАВЛЕНО: Рендерим со ссылкой на фото
          render json: {
            success: true,
            analysis: analysis_result.as_json.merge(
              processed_url: analysis_result.full_processed_url(request.base_url)
            )
          }
        else
          render json: { success: false, message: "Analysis not found" }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Check not found" }, status: :not_found
      end

      def analyze
        check = current_user.checks.find(params[:check_id])

        if check.analysis_result.present?
          return render json: { success: false, message: "Analysis already performed" }, status: :bad_request
        end

        start_time = Time.current
        service = YoloService.new(check)
        analysis_result = service.save_result

        if analysis_result
          processing_time = Time.current - start_time

          LoggingService.log_user_action(current_user, "manual_analysis_trigger", {
            check_id: check.id,
            processing_time: processing_time,
            approved: analysis_result.is_approved
          })
          LoggingService.log_ml_analysis(check, analysis_result, processing_time)

          # ИСПРАВЛЕНО: Финальный ответ для iOS
          render json: {
            success: true,
            analysis: analysis_result.as_json.merge(
              processed_url: analysis_result.full_processed_url(request.base_url)
            ),
            processing_time: processing_time.round(2)
          }
        else
          render json: { success: false, error: "Failed to process image with ML engine" }, status: :internal_server_error
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Check not found" }, status: :not_found
      rescue => e
        LoggingService.log_error(e, { check_id: params[:check_id], user_id: current_user.id })
        render json: { success: false, error: "Internal Error: #{e.message}" }, status: :internal_server_error
      end

      private

      def log_api_request
        LoggingService.log_api_request(request, response, current_user)
      end
    end
  end
end
