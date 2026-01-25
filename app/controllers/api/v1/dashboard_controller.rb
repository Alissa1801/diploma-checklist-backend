module Api
  module V1
    class DashboardController < ApplicationController
      before_action :require_admin
      before_action :log_request
      
      def stats
        begin
          total_checks = Check.count
          approved_checks = Check.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
          rejected_checks = Check.joins(:analysis_result).where(analysis_results: { is_approved: false }).count
          pending_checks = Check.left_joins(:analysis_result).where(analysis_results: { id: nil }).count
          
          avg_score = AnalysisResult.where.not(confidence_score: nil).average(:confidence_score)&.round(2) || 0
          
          checks_with_photo = Check.joins(:photo_attachment).count
          total_photos = ActiveStorage::Attachment.where(record_type: 'Check', name: 'photo').count  # только photo
          
          active_users = User.joins(:checks).distinct.count
          
          recent_checks = Check.includes(:user, :zone, :analysis_result)
                              .order(created_at: :desc)
                              .limit(10)
                              .map do |check|
                                {
                                  id: check.id,
                                  user_email: check.user&.email || 'Unknown',
                                  user_name: check.user ? "#{check.user.first_name} #{check.user.last_name}" : 'Unknown',
                                  zone_name: check.zone&.name || 'Unknown',
                                  status: check.analysis_result&.approved? ? 'approved' : check.analysis_result ? 'rejected' : 'pending',
                                  score: check.analysis_result&.confidence_score,
                                  # ИЗМЕНЕНИЕ: photo_count -> has_photo
                                  has_photo: check.photo.attached?,
                                  photo_url: check.photo.attached? ? rails_blob_url(check.photo) : nil,
                                  submitted_at: check.submitted_at,
                                  feedback: check.analysis_result&.feedback,
                                  confidence: check.analysis_result&.confidence_score
                                }
                              end
          
          # Логируем запрос статистики
          if defined?(LoggingService)
            LoggingService.log_user_action(current_user, 'get_dashboard_stats', {
              total_checks: total_checks,
              approved_checks: approved_checks
            })
          end
          
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
                checks_with_photo: checks_with_photo,  # исправлено имя
                total_photos: total_photos,
                photos_per_check: total_checks > 0 ? (total_photos.to_f / total_checks).round(2) : 0
              },
              users: {
                total_users: User.count,
                active_users: active_users,
                checks_per_user: active_users > 0 ? (total_checks.to_f / active_users).round(2) : 0
              },
              recent_checks: recent_checks,
              timestamp: Time.current
            }
          }
        rescue => e
          Rails.logger.error("Error in dashboard stats: #{e.message}")
          if defined?(LoggingService)
            LoggingService.log_error(e, { action: 'dashboard_stats' })
          end
          render json: { success: false, error: e.message }, status: :internal_server_error
        end
      end
      
      def daily_stats
        begin
          end_date = Time.current
          start_date = 7.days.ago
          
          daily_data = (start_date.to_date..end_date.to_date).map do |date|
            day_start = date.beginning_of_day
            day_end = date.end_of_day
            
            day_checks = Check.where(created_at: day_start..day_end)
            day_approved = day_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
            day_rejected = day_checks.joins(:analysis_result).where(analysis_results: { is_approved: false }).count
            
            {
              date: date.strftime('%Y-%m-%d'),
              day_name: date.strftime('%a'),
              total_checks: day_checks.count,
              approved: day_approved,
              rejected: day_rejected,
              approval_rate: day_checks.count > 0 ? (day_approved.to_f / day_checks.count * 100).round(2) : 0
            }
          end
          
          render json: {
            success: true,
            period: {
              start_date: start_date.strftime('%Y-%m-%d'),
              end_date: end_date.strftime('%Y-%m-%d'),
              days: 7
            },
            daily_stats: daily_data
          }
        rescue => e
          Rails.logger.error("Error in daily stats: #{e.message}")
          if defined?(LoggingService)
            LoggingService.log_error(e, { action: 'daily_stats' })
          end
          render json: { success: false, error: 'Failed to get daily statistics' }, status: :internal_server_error
        end
      end
      
      def user_stats
        begin
          users_stats = User.includes(:checks)
                           .where.not(checks: { id: nil })
                           .map do |user|
                             user_checks = user.checks
                             approved = user_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
                             total = user_checks.count
                             
                             {
                               id: user.id,
                               email: user.email,
                               name: "#{user.first_name} #{user.last_name}",
                               total_checks: total,
                               approved_checks: approved,
                               approval_rate: total > 0 ? (approved.to_f / total * 100).round(2) : 0,
                               last_check: user_checks.maximum(:created_at),
                               avg_score: AnalysisResult.joins(:check)
                                                       .where(checks: { user_id: user.id })
                                                       .where.not(confidence_score: nil)
                                                       .average(:confidence_score)&.round(2) || 0
                             }
                           end
                           .sort_by { |u| -u[:total_checks] }
          
          render json: {
            success: true,
            total_users: User.count,
            users_with_checks: users_stats.count,
            users: users_stats
          }
        rescue => e
          Rails.logger.error("Error in user stats: #{e.message}")
          if defined?(LoggingService)
            LoggingService.log_error(e, { action: 'user_stats' })
          end
          render json: { success: false, error: 'Failed to get user statistics' }, status: :internal_server_error
        end
      end
      
      def zone_stats
        begin
          zones_stats = Zone.all.map do |zone|
            zone_checks = Check.where(zone_id: zone.id)
            approved = zone_checks.joins(:analysis_result).where(analysis_results: { is_approved: true }).count
            total = zone_checks.count
            
            {
              id: zone.id,
              name: zone.name,
              description: zone.description,
              total_checks: total,
              approved_checks: approved,
              rejection_rate: total > 0 ? ((total - approved).to_f / total * 100).round(2) : 0,
              common_issues: AnalysisResult.joins(:check)
                                          .where(checks: { zone_id: zone.id })
                                          .where.not(issues: [])
                                          .pluck(:issues)
                                          .flatten
                                          .tally
                                          .sort_by { |_, count| -count }
                                          .first(5)
                                          .map { |issue, count| { issue: issue, count: count } }
            }
          end
          
          render json: {
            success: true,
            total_zones: Zone.count,
            zones: zones_stats
          }
        rescue => e
          Rails.logger.error("Error in zone stats: #{e.message}")
          if defined?(LoggingService)
            LoggingService.log_error(e, { action: 'zone_stats' })
          end
          render json: { success: false, error: 'Failed to get zone statistics' }, status: :internal_server_error
        end
      end
      
      private
      
      def require_admin
        unless current_user&.admin?
          if defined?(LoggingService)
            LoggingService.log_security_event('unauthorized_dashboard_access', {
              user_id: current_user&.id,
              user_email: current_user&.email,
              ip_address: request.remote_ip
            })
          end
          
          render json: { error: 'Access denied. Admin only.' }, status: :forbidden
        end
      end
      
      def log_request
        # Логируем API запрос
        if defined?(LoggingService)
          LoggingService.log_api_request(request, response, current_user)
        end
      end
    end
  end
end