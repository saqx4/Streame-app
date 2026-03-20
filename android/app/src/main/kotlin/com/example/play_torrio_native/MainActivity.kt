package com.example.play_torrio_native

import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Match the window background to the app's dark theme so any area
        // exposed during a Flutter surface resize (rotation) is the same
        // colour — not white/black.  Everything else (immersive mode,
        // orientation, system-bar visibility) is handled by Flutter's
        // SystemChrome from the Dart side to avoid conflicts.
        window.decorView.setBackgroundColor(0xFF0B0B12.toInt())
    }
}
