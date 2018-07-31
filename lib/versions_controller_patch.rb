module VersionList
  module VersionsControllerPatch
    def self.included base
      base.class_eval do
        helper :queries
        include QueriesHelper

        def index_with_filter
          retrieve_query

          respond_to do |format|
            format.html {
              @trackers = @project.trackers.sorted.to_a
              @issue_statuses = IssueStatus.sorted.to_a
              load_issue_statuses
              retrieve_selected_tracker_ids(@trackers, @trackers.select {|t| t.is_in_roadmap?})
              retrieve_selected_status_ids(@issue_statuses, @issue_statuses)
              @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
              project_ids = @with_subprojects ? @project.self_and_descendants.collect(&:id) : [@project.id]

              @versions = @project.shared_versions.preload(:custom_values)
              @versions += @project.rolled_up_versions.visible.preload(:custom_values) if @with_subprojects
              @versions = @versions.to_a.uniq.sort
              unless params[:completed]
                @completed_versions = @versions.select(&:completed?).reverse
                @versions -= @completed_versions
              end
              @query.issues
              @issues_by_version = {}
              @issues_by_version = @query.issues.group_by(&:fixed_version)
              order_option = [@query.group_by_sort_order, @query.sort_clause].flatten.reject(&:blank?)

              if @selected_tracker_ids.any? && @versions.any?
                issues = Issue.visible.
                  joins(:status, :assigned_to).
                  includes(:project, :tracker).
                  preload(:status, :priority, :fixed_version).
                  where(status_id: @selected_status_ids, tracker_id: @selected_tracker_ids, project_id: project_ids, fixed_version_id: @versions.map(&:id)).
                  order(order_option)
                @issues_by_version = issues.group_by(&:fixed_version)
              end
              
              @versions.reject! {|version| !project_ids.include?(version.project_id) && @issues_by_version[version].blank?}
            }
            format.api {
              @versions = @project.shared_versions.to_a
            }
          end
        end

        def retrieve_selected_status_ids(selectable_trackers, default_trackers=nil)
          if params[:status_ids] && params[:status_ids].include?("OPEN_STT")
            params[:status_ids].delete("OPEN_STT")
            params[:status_ids] += @open_status_ids
          end
          if ids = params[:status_ids]
            @selected_status_ids = (ids.is_a? Array) ? ids.collect { |id| id.to_i.to_s } : ids.split('/').collect { |id| id.to_i.to_s }
          else
            @selected_status_ids = (default_trackers || selectable_trackers).collect {|t| t.id.to_s }
          end
        end

        def load_issue_statuses
          @open_status_ids = IssueStatus.where("name LIKE 'new' OR name LIKE 'in progress' OR name LIKE 'reopen'")
            .pluck(:id).collect { |id| id.to_i.to_s }
          @resolved_status_id = IssueStatus.where("LOWER(name) = 'resolved'").first.try :id
          @deployed_status_id = IssueStatus.where("LOWER(name) = 'deployed'").first.try :id
        end

        alias_method :index, :index_with_filter
      end
    end
  end
end
