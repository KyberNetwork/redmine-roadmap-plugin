module ProjectPatch
  def self.included base
    base.class_eval do
      has_many :enumerations
    end
  end
end
