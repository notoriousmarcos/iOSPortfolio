require 'xcodeproj'

def updateRunnableReference(target, scheme)
    project_path = './NotoriousHunt.xcodeproj'
    project = project = Xcodeproj::Project.open(project_path)
    
    xscheme_path = "./NotoriousHunt.xcodeproj/xcshareddata/xcschemes/#{scheme}.xcscheme"
    scheme = Xcodeproj::XCScheme.new(xscheme_path)
    target_reference = project.targets.find { |t| t.name == target }

    continuous_executable = Xcodeproj::XCScheme::BuildableProductRunnable.new(target_reference, 0)
    scheme.launch_action.buildable_product_runnable = continuous_executable
    scheme.save!
end

updateRunnableReference("NotoriousHunt", "NotoriousHunt Debug")
updateRunnableReference("NotoriousHunt", "NotoriousHunt Test")
