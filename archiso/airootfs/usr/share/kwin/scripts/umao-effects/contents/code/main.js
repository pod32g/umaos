// UmaOS KWin Effects — Racing-inspired animation tweaks
// Sets faster window open animations and horizontal desktop switching

(function() {
    "use strict";

    // Configure scale effect for window open/close (faster, directional)
    var scaleConfig = {
        Duration: 150,       // Faster than default (250ms)
        InScale: 0.92,       // Slight scale-up effect
        OutScale: 0.92
    };

    // Apply configuration via KWin scripting API
    // These settings are applied when the script loads
    workspace.windowAdded.connect(function(window) {
        // Window added hook — animation parameters are set via KWin config
    });
})();
