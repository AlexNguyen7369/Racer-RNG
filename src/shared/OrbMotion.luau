--!nonstrict
-- Singularity orb motion (docs/CAR_REDESIGN_SPEC.md section 11): pure maths, so every client and the tests agree.
-- Offset(t) is added to each orb part's rest CFrame about its own centre (the parts rest upright; the ring tilt is
-- baked into the mesh), so the spin is about the vertical axis.
local OrbMotion = {}

OrbMotion.SPIN_SPEED = 1.5 -- radians per second (placeholder)
OrbMotion.BOB_HEIGHT = 0.15 -- studs, bob amplitude (placeholder)
OrbMotion.BOB_RATE = 2 -- radians per second (placeholder)

function OrbMotion.Offset(t, reduced)
	if reduced then -- reduced motion: no bob, a third of the spin
		return CFrame.Angles(0, t * OrbMotion.SPIN_SPEED / 3, 0)
	end
	return CFrame.new(0, math.sin(t * OrbMotion.BOB_RATE) * OrbMotion.BOB_HEIGHT, 0)
		* CFrame.Angles(0, t * OrbMotion.SPIN_SPEED, 0)
end

return OrbMotion
