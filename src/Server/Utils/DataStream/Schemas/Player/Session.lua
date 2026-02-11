return {
	PlotInstance = nil,

	Run = {
		IsActive = false,
		IsFrozen = false,
		StepsRemaining = 0,
		StepsTaken = 0,
		DistanceTraveled = 0,
		LastCheckpointIndex = 0,
		PendingMomentum = 0,
		PendingXP = 0,
		LastValidatedPosition = nil,
		LastValidationTime = 0,
	},
}