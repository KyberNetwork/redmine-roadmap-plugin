require 'versions_controller_patch'
Redmine::Plugin.register :roadmap do
  name 'Roadmap plugin'
  author 'Vinh Ng'
  description 'This is a plugin for roadmap of Redmine'
  version '0.0.1'

  Rails.configuration.to_prepare do 
    VersionsController.send(:include, VersionList::VersionsControllerPatch)
    Project.send(:include, ProjectPatch)
  end
end
