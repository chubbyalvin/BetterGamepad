return {
    ---------------------------------------------------------------------------
    -- Multi-Action Button
    ---------------------------------------------------------------------------
    -- Physical controller button BetterGamepad treats as MultiAction.
    -- Gamepad_FaceButton_Left = Square on PlayStation / X on Xbox.
    -- This is independent of Palworld's native ReloadAndCoop binding.
    MultiActionButton = "Gamepad_FaceButton_Left",

    ---------------------------------------------------------------------------
    -- Multi-Action Features
    ---------------------------------------------------------------------------
    -- Short tap: Reload when appropriate.
    EnableReload = true,

    -- Short tap / aim behavior: allow melee attacks with melee weapons.
    EnableMeleeOnMultiAction = true,

    -- Hold/tap behavior: Coop / Partner Skill / Ride / Dismount routing.
    EnableCoop = true,

    ---------------------------------------------------------------------------
    -- Riding Skills
    ---------------------------------------------------------------------------
    -- Allow Riding Skill 1 while aiming when Skill 1 is bound to a different
    -- physical button from WeaponUse/Fire. BetterGamepad reads both bindings
    -- dynamically and bypasses only RidingSkill1's native aim suppression.
    -- If Skill 1 shares a button with WeaponUse (vanilla R2), BetterGamepad leaves
    -- that action fully native: R2 = Skill 1 when not aiming, Fire when aiming.
    EnableRidingSkill1WhileAiming = true,

    ---------------------------------------------------------------------------
    -- Coop / Partner Skill Behavior
    ---------------------------------------------------------------------------
    -- "Hold" = trigger Coop after PartnerSkillHoldMs.
    -- "Tap"  = give Coop priority on a short MultiAction tap.
    PartnerSkillTrigger = "Hold",

    -- Hold duration required before Coop activates when PartnerSkillTrigger="Hold".
    PartnerSkillHoldMs = 350,

    -- How long an armed Partner Skill can wait for a Pal activation/swap.
    -- 0 = stays armed until used/cleared.
    PartnerSkillArmTimeout = 0,
}
