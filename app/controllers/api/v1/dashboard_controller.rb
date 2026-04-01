module Api
  module V1
    class DashboardController < ApplicationController
      before_action :require_admin, except: [:personal_stats]
      before_action :log_request
      before_action :authorize_personal_stats, only: [:personal_stats]
      
     # Общая статистика для администратора (GET /api/v1/dashboard/stats)
  def stats
    begin
      date_range = get_date_range(params[:period])
      
      # Базовая выборка чеков с учетом периода
      base_checks = Check.all
      base_checks = base_checks.where(created_at: date_range) if date_range

      total_checks = base_checks.count
      approved_checks = base_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
      rejected_checks = base_checks.joins(:analysis_result).where(analysis_results: { is_approved: false }).count
      pending_checks = base_checks.left_joins(:analysis_result).where(analysis_results: { id: nil }).count
      
      # Расчет среднего балла
      avg_score = AnalysisResult.joins(:check)
                               .where(checks: { id: base_checks.select(:id) })
                               .where.not(confidence_score: nil)
                               .average(:confidence_score)&.round(2) || 0
      
      checks_with_photo = base_checks.joins(:photo_attachment).count
      active_users_count = base_checks.distinct.pluck(:user_id).compact.count
      
      # --- ИНТЕГРАЦИЯ LEADERBOARD ---
      # Собираем данные только по сотрудникам (cleaners)
      leaderboard_data = User.where(role: :cleaner).map do |user|
        # Берем чеки конкретного пользователя за выбранный период
        user_checks = base_checks.where(user_id: user.id)
        u_total = user_checks.count
        
        # Считаем брак (rejected) через связь с analysis_results
        u_rejected = user_checks.joins(:analysis_result)
                                .where(analysis_results: { is_approved: false })
                                .count

        {
          id: user.id,
          full_name: user.full_name || user.email, # если имя не заполнено, берем email
          total_checks: u_total,
          rejected_count: u_rejected,
          # Процент качества: (успешные / всего) * 100
          quality_score: u_total > 0 ? (((u_total - u_rejected).to_f / u_total) * 100).round(1) : 0
        }
      end

      # Сортировка: сначала те, у кого МЕНЬШЕ rejected_count. 
      # Если брак одинаковый, то выше тот, у кого БОЛЬШЕ общее количество чеков.
      leaderboard_data = leaderboard_data.sort_by { |u| [u[:rejected_count], -u[:total_checks]] }
      # --- КОНЕЦ ИНТЕГРАЦИИ ---

      # Список последних проверок
      recent_checks = base_checks.includes(:user, :zone, :analysis_result)
                                 .order(created_at: :desc)
                                 .limit(10)
                                 .map { |check| format_check_data(check) }

      render json: {
        success: true,
        stats: {
          overview: {
            total_checks: total_checks,
            approved: approved_checks,
            rejected: rejected_checks,
            pending: pending_checks,
            approval_rate: total_checks > 0 ? (approved_checks.to_f / total_checks * 100).round(2) : 0
          },
          quality: {
            average_score: avg_score,
            checks_with_photo: checks_with_photo,
            photos_per_check: total_checks > 0 ? (checks_with_photo.to_f / total_checks).round(2) : 0
          },
          users: {
            total_users: User.count,
            active_users: active_users_count,
            checks_per_user: active_users_count > 0 ? (total_checks.to_f / active_users_count).round(2) : 0
          },
          leaderboard: leaderboard_data, # Новое поле в ответе
          recent_checks: recent_checks,
          timestamp: Time.current
        }
      }
    rescue => e
      render_error(e, 'dashboard_stats')
    end
  end
      
      # Личная статистика пользователя (GET /api/v1/dashboard/personal_stats)
# Личная статистика пользователя (GET /api/v1/dashboard/personal_stats)
def personal_stats
  begin
    user = User.find(params[:user_id])
    date_range = get_date_range(params[:period])
    
    # Выборка чеков конкретного пользователя с учетом фильтра даты
    user_checks = user.checks
    user_checks = user_checks.where(created_at: date_range) if date_range

    total_checks = user_checks.count
    approved_checks = user_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
    rejected_checks = user_checks.joins(:analysis_result).where(analysis_results: { is_approved: false }).count
    pending_checks = user_checks.left_joins(:analysis_result).where(analysis_results: { id: nil }).count
    
    # Расчет среднего балла
    avg_score = AnalysisResult.joins(:check)
                             .where(checks: { user_id: user.id, id: user_checks.select(:id) })
                             .where.not(confidence_score: nil)
                             .average(:confidence_score)&.round(2) || 0
    
    checks_with_photo = user_checks.joins(:photo_attachment).count

    # Форматирование последних проверок
    recent_personal_checks = user_checks.includes(:zone, :analysis_result)
                                       .order(created_at: :desc)
                                       .limit(10)
                                       .map { |check| format_check_data(check) }
    
    # Статистика по зонам
    zones_stats = Zone.joins(:checks)
                     .where(checks: { user_id: user.id, id: user_checks.select(:id) })
                     .distinct
                     .map do |zone|
                       zone_total = zone.checks.where(user_id: user.id, id: user_checks.select(:id)).count
                       zone_approved = zone.checks.joins(:analysis_result)
                                           .where(user_id: user.id, id: user_checks.select(:id), analysis_results: { is_approved: true }).count
                       {
                         id: zone.id,
                         name: zone.name,
                         total_checks: zone_total,
                         approved_checks: zone_approved,
                         approval_rate: zone_total > 0 ? (zone_approved.to_f / zone_total * 100).round(2) : 0
                       }
                     end

    render json: {
      success: true,
      user_info: {
        id: user.id,
        email: user.email,
        name: user.full_name,
        role: user.role
      },
      stats: {
        overview: {
          total_checks: total_checks,
          approved: approved_checks,
          rejected: rejected_checks,
          pending: pending_checks,
          approval_rate: total_checks > 0 ? (approved_checks.to_f / total_checks * 100).round(2) : 0
        },
        quality: {
          average_score: avg_score,
          checks_with_photo: checks_with_photo,
          # Гарантируем наличие поля photos_per_check для Swift
          photos_per_check: total_checks > 0 ? (checks_with_photo.to_f / total_checks).round(2) : 0.0
        },
        # Пустые/нулевые поля для соответствия модели DashboardStats в приложении
        users: nil,
        leaderboard: [],
        zones: zones_stats,
        recent_checks: recent_personal_checks,
        timestamp: Time.current.iso8601
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'User not found' }, status: :not_found
  rescue => e
    render_error(e, 'personal_stats')
  end
end

      # Статистика по дням (для графиков)
      def daily_stats
        begin
          end_date = Time.current
          start_date = 7.days.ago
          
          daily_data = (start_date.to_date..end_date.to_date).map do |date|
            day_checks = Check.where(created_at: date.all_day)
            day_approved = day_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
            
            {
              date: date.strftime('%Y-%m-%d'),
              day_name: date.strftime('%a'),
              total_checks: day_checks.count,
              approved: day_approved,
              approval_rate: day_checks.count > 0 ? (day_approved.to_f / day_checks.count * 100).round(2) : 0
            }
          end
          
          render json: { success: true, daily_stats: daily_data }
        rescue => e
          render_error(e, 'daily_stats')
        end
      end

      # Рейтинг пользователей
      def user_stats
        begin
          users_stats = User.includes(:checks).where.not(role: 'admin')
                           .map do |user|
                             total = user.checks.count
                             next if total == 0
                             approved = user.checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
                             
                             {
                               id: user.id,
                               email: user.email,
                               name: user.full_name,
                               total_checks: total,
                               approved_checks: approved,
                               approval_rate: (approved.to_f / total * 100).round(2)
                             }
                           end.compact.sort_by { |u| -u[:total_checks] }
          
          render json: { success: true, users: users_stats }
        rescue => e
          render_error(e, 'user_stats')
        end
      end

      # Статистика по зонам
      def zone_stats
        begin
          zones_stats = Zone.all.map do |zone|
            total = zone.checks.count
            approved = zone.checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
            {
              id: zone.id,
              name: zone.name,
              total_checks: total,
              approved_checks: approved,
              rejection_rate: total > 0 ? (((total - approved).to_f / total) * 100).round(2) : 0
            }
          end
          render json: { success: true, zones: zones_stats }
        rescue => e
          render_error(e, 'zone_stats')
        end
      end

      private

      # Определение временного диапазона
      def get_date_range(period)
        case period
        when 'day'
          Time.current.all_day
        when 'week'
          Time.current.all_week
        when 'month'
          Time.current.all_month
        else
          nil
        end
      end

      # Единый формат для RecentCheck
      def format_check_data(check, user = nil)
        target_user = user || check.user
        {
          id: check.id,
          room_number: check.room_number,
          user_email: target_user&.email || 'Unknown',
          user_name: target_user&.full_name || 'Unknown',
          zone_name: check.zone&.name || 'Unknown',
          status: check.status,
          score: check.analysis_result&.confidence_score,
          has_photo: check.photo.attached?,
          photo_url: check.photo.attached? ? rails_blob_url(check.photo) : nil,
          submitted_at: check.submitted_at,
          feedback: check.analysis_result&.feedback,
          confidence: check.analysis_result&.confidence_score
        }
      end

      def render_error(e, action_name)
        Rails.logger.error("Error in #{action_name}: #{e.message}")
        LoggingService.log_error(e, { action: action_name }) if defined?(LoggingService)
        render json: { success: false, error: "Internal Server Error" }, status: :internal_server_error
      end

      def require_admin
        render json: { error: 'Access denied' }, status: :forbidden unless current_user&.admin?
      end

      def authorize_personal_stats
        user_id = params[:user_id].to_i
        unless current_user && (current_user.id == user_id || current_user.admin?)
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def log_request
        LoggingService.log_api_request(request, response, current_user) if defined?(LoggingService)
      end
    end
  end
end