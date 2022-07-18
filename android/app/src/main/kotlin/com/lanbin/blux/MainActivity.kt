package com.lanbin.blux

import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity
// import com.ryanheise.audioservice.AudioServiceFragmentActivity;

class MainActivity: FlutterFragmentActivity() {
    override fun onStart() {
        super.onStart()
        window.decorView.visibility = View.VISIBLE
    }

    override fun onStop() {
        window.decorView.visibility = View.GONE
        super.onStop()
    }
}
