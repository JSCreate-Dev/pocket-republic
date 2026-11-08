# 2026-11-08 12:05 PM EST — Ios Dev — ui/placement-feedback

Base e6508e8. Jordan reported never knowing whether placement succeeded.

Game.send returns a discardable Bool for core acceptance; saveIssue remains independent. Only accepted placement can create a receipt or success haptic. The receipt shows building, cost, opening time and live saved/unsaved status. The construction site is selected in the scene without automatically opening a tall panel; View construction site focuses and inspects it. Receipt dismiss/removal/new-city reset are explicit. Rejection leaves the preview and shows an error.

One finger in building mode moves the preview, not the camera. Two-finger navigation stays latched until all fingers lift. Delayed callbacks check the active tool and tab. The inspector/road gesture policies are otherwise unchanged. Place shows cost and copy distinguishes preview from confirmation.

Swift 6.2 syntax parsing and git diff --check passed. No Xcode typecheck, physical gesture, visual layout, VoiceOver or persistence-failure test is claimed. Claude must build the IPA and Jordan should try placement, rejected placement, pinch then finger lift, cancel, View site, dismiss and reopen. Road interpolation, cancellation rollback, terrain depth, elevation and improved hit-testing remain future work.
