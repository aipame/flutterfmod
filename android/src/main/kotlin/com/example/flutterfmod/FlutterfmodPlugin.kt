package com.example.flutterfmod

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.io.IOException
import java.lang.Boolean
import java.lang.Exception
import java.lang.RuntimeException
import kotlinx.coroutines.GlobalScope


/** FlutterfmodPlugin */
class FlutterfmodPlugin: FlutterPlugin, MethodCallHandler, MediaPlayer.OnCompletionListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var filePath: String? = null

  private var mMediaRecorder: MediaRecorder? = null

  private var mediaPlayer: MediaPlayer? = null

  private val mainHandler: Handler = Handler(Looper.getMainLooper())
  private var context: Context? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutterfmod")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when {
      call.method.equals("startVoiceRecord") -> {
        this.startRecord(result)
      }
      call.method.equals("stopVoiceRecord") -> {
        this.stopRecord(result)
      }
      call.method.equals("cancelVoiceRecord") -> {
        this.cancelRecord(result)
      }
      call.method.equals("play") -> {
        val path =  call.argument<String>("path").toString()
        this.play(path, result)
      }
      call.method.equals("stopPlaying") -> {
        this.stop(result)
      }
      call.method == "conversion" -> {
        val conversionType = call.argument<Number>("conversionType")
        val path = call.argument<String>("path").toString()
        var savePath = call.argument<String>("savePath")
        val randoms = (0..10).random()
        var wavPath = context?.cacheDir?.path.toString() + "/conversion_" + randoms.toString() + ".wav"
        savePath = savePath ?:context?.cacheDir?.path.toString() + "/conversion_" + randoms.toString() + ".amr"
        wavPath = AmrToWav.makeAmrToWav(path, wavPath, Boolean.valueOf(false))

        GlobalScope.launchUI{


        FmodSound.saveSoundAsync(wavPath, conversionType as Int, savePath, object : FmodSound.ISaveSoundListener {
          override fun onFinish(path: String, savePath: String, type: Int) {
            result.success(savePath)
            context?.showToast("转换完成$savePath")
          }

          override fun onError(msg: String?) {
            context?.showToast("转换失败$savePath")

            result.error("100001",msg,null)
          }
        })
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private var startTime: Long = 0

  // 开始录音
  private fun startRecord(result: Result) {
    if (mMediaRecorder == null) mMediaRecorder = MediaRecorder()
    try {
      startTime = System.currentTimeMillis()
      mMediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC) // 设置麦克风
      mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB)
      mMediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
      mMediaRecorder?.setAudioChannels(1) // MONO
      mMediaRecorder?.setAudioSamplingRate(8000) // 8000Hz
      mMediaRecorder?.setAudioEncodingBitRate(64) // seems if change this to
      filePath = context?.cacheDir?.path.toString() + "/" + startTime + ".amr"
      mMediaRecorder?.setOutputFile(filePath)
      mMediaRecorder?.prepare()
      mMediaRecorder?.start()
      updateMicStatus()
      result.success(Boolean.valueOf(true))
    } catch (e: Exception) {
      mMediaRecorder?.reset()
      mMediaRecorder?.release()
      mMediaRecorder = null
      filePath = ""
      result.success(Boolean.valueOf(false))
    }
  }

  // 停止录音
  private fun stopRecord(result: Result) {
    val map: MutableMap<String, Any> = HashMap()
    map["duration"] = 0L
    map["path"] = ""
    do {
      try {
        if (mMediaRecorder == null) {
          break
        } else {
          mMediaRecorder?.stop()
          map["duration"] = (System.currentTimeMillis() - startTime) / 1000
          map["path"] = filePath!!
          mMediaRecorder?.reset()
          mMediaRecorder?.release()
          filePath = ""
          break
        }
      } catch (e: RuntimeException) {
        val file = File(filePath)
        if (file.exists()) {
          file.delete()
        }
      } finally {
        mMediaRecorder = null
        filePath = ""
      }
    } while (false)
    result.success(map)
  }

  private fun cancelRecord(result: Result) {
    mMediaRecorder?.stop()
    mMediaRecorder?.reset()
    mMediaRecorder?.release()
    mMediaRecorder = null
    filePath = ""
    result.success(Boolean.valueOf(true))
  }

  private fun play(path: String, result: Result) {
    if (mediaPlayer != null && filePath == path) {
      result.success(Boolean.TRUE)
      return
    } else {
      if (filePath != null) {
        stop(null)
      }
    }
    stop(null)
    filePath = path
    mediaPlayer = MediaPlayer()
    try {
      mediaPlayer?.setDataSource(path)
      mediaPlayer?.setOnCompletionListener(this)
      mediaPlayer?.prepare()
      mediaPlayer?.start()
      result.success(Boolean.TRUE)
    } catch (e: IOException) {
      result.success(Boolean.FALSE)
      e.printStackTrace()
    }
  }

  private fun stop(result: Result?) {
    if (mediaPlayer != null) {
      if (mediaPlayer?.isPlaying() == true) {
        mediaPlayer?.stop()
      }
      mediaPlayer?.reset()
      mediaPlayer?.release()
      mediaPlayer = null
    }
    if (result != null) {
      val map = HashMap<Any, Any>()
      map["error"] = Boolean.FALSE
      map["path"] = filePath ?: ""
      channel.invokeMethod("stopPlaying", map)
    }
    filePath = null
  }

  private val BASE = 3000.0
  private val SPACE = 300 // 间隔取样时间


  // 获取麦克风音量大小
  private fun updateMicStatus() {
    if (mMediaRecorder != null) {
      var ratio = (mMediaRecorder?.maxAmplitude?.toDouble() ?: 0.0)  / BASE
      var db = 0.0 // 分贝
      if (ratio > 1) ratio = 1.0
      db = ratio
      val finalDb = db
      mainHandler.post { channel.invokeMethod("volume", finalDb) }
      mHandler.postDelayed(mUpdateMicStatusTimer, SPACE.toLong())
    }
  }

  private val mHandler = Handler()
  private val mUpdateMicStatusTimer = Runnable { updateMicStatus() }

  override fun onCompletion(mediaPlayer: MediaPlayer) {
    mediaPlayer?.stop()
    mediaPlayer?.reset()
    mediaPlayer?.release()
    this.mediaPlayer = null
    val map = HashMap<Any, Any>()
    map["error"] = Boolean.FALSE
    map["path"] = filePath ?: ""
    channel.invokeMethod("stopPlaying", map)
    filePath = null
  }
  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
