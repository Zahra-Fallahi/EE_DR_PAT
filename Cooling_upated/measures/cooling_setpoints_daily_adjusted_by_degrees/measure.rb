# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio-extension'
require 'openstudio/extension/core/os_lib_helper_methods.rb'
require 'openstudio/extension/core/os_lib_schedules.rb'

# start the measure
class CoolingSetpointsDailyAdjustedByDegrees < OpenStudio::Measure::ModelMeasure
  # resource file modules
	include OsLib_HelperMethods
	include OsLib_Schedules
	
	# human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'CoolingSetpointsDailyAdjustedByDegrees'
  end

  # human readable description
  def description
    return 'Sets cooling setpoint for each hour of the day.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Sets cooling setpoint for each hour of the day.  Each hourly value is a separate argument (to allow for optimization at each hour of the day).'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
		
		for i in 1..24
			argument_name = "hour_#{i}_setpoint"
			display_name = "Hour #{i} Setpoint"
			arg = OpenStudio::Ruleset::OSArgument::makeDoubleArgument(argument_name, true)
			arg.setDisplayName(display_name)
			args << arg
		end

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

	  # assign the user inputs to variables
		args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments(model))
		unless args
			return false
		end

		# create replacement schedule
		ruleset_name = "optimized_cooling_setpoint_schedule"
		design_day_schedule_array = []
		default_day_schedule_array = ["AllDays"]
		for i in 1..24
			design_day_schedule_array << [i,args["hour_#{i}_setpoint"]]
			default_day_schedule_array << [i,args["hour_#{i}_setpoint"]]
		end
		winter_design_day = design_day_schedule_array
    summer_design_day = design_day_schedule_array
		default_day = default_day_schedule_array
		
    options = {"name" => ruleset_name,
               "winter_design_day" => winter_design_day,
               "summer_design_day" => summer_design_day,
               "default_day" => default_day}
    new_clg_set_sch = OsLib_Schedules.createComplexSchedule(model, options)

    runner.registerInfo("Added schedule #{new_clg_set_sch.name}")
		
		# replace existing thermostat schedules
		thermostats = model.getThermostatSetpointDualSetpoints
		thermostats.each do |thermostat|
			# check for existing cooling setpoint schedule
		  clg_set_sch = thermostat.coolingSetpointTemperatureSchedule
		  if not clg_set_sch.empty?
				#set cooling setpoint schedule
				thermostat.setCoolingSetpointTemperatureSchedule(new_clg_set_sch)
			else
		    runner.registerWarning("Thermostat '#{thermostat.name.to_s}' doesn't have a cooling setpoint schedule.  Not assigning new setpoint schedule.")
			end
		end #end thermostats.each do

    return true
  end
end

# register the measure to be used by the application
CoolingSetpointsDailyAdjustedByDegrees.new.registerWithApplication
