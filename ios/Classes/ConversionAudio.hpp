//
//  ConversionAudio.hpp
//  flutterfmod
//
//  Created by Mac on 2021/11/15.
//

#ifndef ConversionAudio_hpp
#define ConversionAudio_hpp

#include <stdio.h>
#import "fmod.hpp"
#include <string>
#include <thread>


#define MODE_NORMAL 0
#define MODE_FUNNY 1
#define MODE_UNCLE 2
#define MODE_LOLITA 3
#define MODE_ROBOT 4
#define MODE_ETHEREAL 5
#define MODE_CHORUS 6
#define MODE_HORROR 7


using namespace FMOD;

Channel *channel;

extern "C"
int FmodSoundSaveSound(  const char *path_cstr , int type, const char *save_cstr) {
    Sound *sound = nullptr;
    DSP *dsp;
    bool playing = true;
    float frequency = 0;
    System *mSystem;
    
    int code = 0;
    System_Create(&mSystem);
  
    try {
        if (save_cstr != NULL) {
            char cDest[200];
            strcpy(cDest, save_cstr);
            mSystem->setSoftwareFormat(8000, FMOD_SPEAKERMODE_MONO, 0); //设置采样率为8000，channel为1
            mSystem->setOutput(FMOD_OUTPUTTYPE_WAVWRITER); //保存文件格式为WAV
            mSystem->init(32, FMOD_INIT_NORMAL, cDest);
            mSystem->recordStart(0, sound, true);
        }
        //创建声音
        mSystem->createSound(path_cstr, FMOD_DEFAULT, NULL, &sound);
        mSystem->playSound(sound, 0, false, &channel);
//        printf("saveAiSound-%s", "save_start")
        switch (type) {
            case MODE_NORMAL:
                printf("saveAiSound-%s", "save MODE_NORMAL");
                break;
            case MODE_FUNNY:
                printf("saveAiSound-%s", "save MODE_FUNNY");
                mSystem->createDSPByType(FMOD_DSP_TYPE_NORMALIZE, &dsp);
                channel->getFrequency(&frequency);
                frequency = frequency * 1.6;
                channel->setFrequency(frequency);
                break;
            case MODE_UNCLE:
                printf("saveAiSound-%s", "save MODE_UNCLE");
                mSystem->createDSPByType(FMOD_DSP_TYPE_PITCHSHIFT, &dsp);
                dsp->setParameterFloat(FMOD_DSP_PITCHSHIFT_PITCH, 0.8);
                channel->addDSP(0, dsp);
                break;
            case MODE_LOLITA:
                printf("saveAiSound-%s", "save MODE_LOLITA");
                mSystem->createDSPByType(FMOD_DSP_TYPE_PITCHSHIFT, &dsp);
                dsp->setParameterFloat(FMOD_DSP_PITCHSHIFT_PITCH, 1.8);
                channel->addDSP(0, dsp);
                break;
            case MODE_ROBOT:
                printf("saveAiSound-%s", "save MODE_ROBOT");
                mSystem->createDSPByType(FMOD_DSP_TYPE_ECHO, &dsp);
                dsp->setParameterFloat(FMOD_DSP_ECHO_DELAY, 50);
                dsp->setParameterFloat(FMOD_DSP_ECHO_FEEDBACK, 60);
                channel->addDSP(0, dsp);
                break;
            case MODE_ETHEREAL:
                printf("saveAiSound-%s", "save MODE_ETHEREAL");
                mSystem->createDSPByType(FMOD_DSP_TYPE_ECHO, &dsp);
                dsp->setParameterFloat(FMOD_DSP_ECHO_DELAY, 300);
                dsp->setParameterFloat(FMOD_DSP_ECHO_FEEDBACK, 20);
                channel->addDSP(0, dsp);
                break;
            case MODE_CHORUS:
                printf("saveAiSound-%s", "save MODE_CHORUS");
                mSystem->createDSPByType(FMOD_DSP_TYPE_ECHO, &dsp);
                dsp->setParameterFloat(FMOD_DSP_ECHO_DELAY, 100);
                dsp->setParameterFloat(FMOD_DSP_ECHO_FEEDBACK, 50);
                channel->addDSP(0, dsp);
                break;
            case MODE_HORROR:
                printf("saveAiSound-%s", "save MODE_HORROR");
                mSystem->createDSPByType(FMOD_DSP_TYPE_TREMOLO, &dsp);
                dsp->setParameterFloat(FMOD_DSP_TREMOLO_SKEW, 0.8);
                channel->addDSP(0, dsp);
                break;
            default:
                break;
        }
        mSystem->update();
    } catch (...) {
        printf("saveAiSound-%s", "save error!");
        code = 1;
        goto end;
    }
    while (playing) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        
        channel->isPlaying(&playing);
    }
    printf("saveAiSound-%s", "save over!");
    goto end;
    end:
   
    sound->release();
    mSystem->close();
    mSystem->release();
    return code;
}


#endif /* ConversionAudio_hpp */
