package com.oney.WebRTCModule;

/**
 * Created by sunny on 9/19/16.
 */

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.Context;
import android.os.Build;
import android.telephony.PhoneStateListener;
import android.telephony.SignalStrength;
import android.util.Log;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Timer;
import java.util.TimerTask;

public class CustomPhoneStateListener extends PhoneStateListener {

    private static final int BANDWIDTH_2G = 180;
    private static final int BANDWIDTH_3G = 750;
    private static final int BANDWIDTH_LTE = 1024;
    private static final int BANDWIDTH_WIFI = 2048;
    private static final int MAX_SIGNAL_STRENGTH = 5;
    public Timer myTimer;
    public TimerTask myTimerTask;
    private int newBandwidth = CustomPhoneStateListener.BANDWIDTH_WIFI;

    private Context mContext;
    public static String LOG_TAG = "CustomPhoneStateListener";

    @SuppressLint("LongLogTag")
    public CustomPhoneStateListener(Context context) {
        mContext = context;
        this.myTimer = new Timer();
        this.myTimerTask = new TimerTask() {

            final int bandwidth = newBandwidth;

            @Override
            public void run() {
                Log.d(LOG_TAG, "Adjusted SDP Bandwidth to" + CustomPhoneStateListener.BANDWIDTH_3G);

                WebRTCModule.changeBandwidthResolution(bandwidth);
            }
        };
    }

    /**
     * In this method Java Reflection API is being used please see link before
     * using.
     *
     * @see <a
     * href="http://docs.oracle.com/javase/tutorial/reflect/">http://docs.oracle.com/javase/tutorial/reflect/</a>
     */
    @TargetApi(Build.VERSION_CODES.M)
    @SuppressLint("LongLogTag")
    @Override
    public void onSignalStrengthsChanged(final SignalStrength signalStrength) {
        super.onSignalStrengthsChanged(signalStrength);

        newBandwidth = ((signalStrength.getLevel() + 1) * CustomPhoneStateListener.BANDWIDTH_WIFI) / CustomPhoneStateListener.MAX_SIGNAL_STRENGTH;

        Log.i(LOG_TAG, "onSignalStrengthsChanged: " + signalStrength);
        if (signalStrength.isGsm()) {
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getGsmBitErrorRate "
                    + signalStrength.getGsmBitErrorRate());
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getGsmSignalStrength "
                    + signalStrength.getGsmSignalStrength());
            newBandwidth = ((signalStrength.getLevel() + 1) * CustomPhoneStateListener.BANDWIDTH_3G) / CustomPhoneStateListener.MAX_SIGNAL_STRENGTH;
        } else if (signalStrength.getCdmaDbm() > 0) {
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getCdmaDbm "
                    + signalStrength.getCdmaDbm());
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getCdmaEcio "
                    + signalStrength.getCdmaEcio());
            newBandwidth = ((signalStrength.getLevel() + 1) * CustomPhoneStateListener.BANDWIDTH_3G) / CustomPhoneStateListener.MAX_SIGNAL_STRENGTH;
        } else {
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getEvdoDbm "
                    + signalStrength.getEvdoDbm());
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getEvdoEcio "
                    + signalStrength.getEvdoEcio());
            Log.i(LOG_TAG, "onSignalStrengthsChanged: getEvdoSnr "
                    + signalStrength.getEvdoSnr());
            newBandwidth = ((signalStrength.getLevel() + 1) * CustomPhoneStateListener.BANDWIDTH_3G) / CustomPhoneStateListener.MAX_SIGNAL_STRENGTH;
        }

        // Reflection code starts from here
        try {
            Method[] methods = android.telephony.SignalStrength.class
                    .getMethods();
            for (Method mthd : methods) {
                if (mthd.getName().equals("getLteSignalStrength")
                        || mthd.getName().equals("getLteRsrp")
                        || mthd.getName().equals("getLteRsrq")
                        || mthd.getName().equals("getLteRssnr")
                        || mthd.getName().equals("getLteCqi")) {
                    Log.i(LOG_TAG,
                            "onSignalStrengthsChanged: " + mthd.getName() + " "
                                    + mthd.invoke(signalStrength));
                    newBandwidth = ((signalStrength.getLevel() + 1) * CustomPhoneStateListener.BANDWIDTH_LTE) / CustomPhoneStateListener.MAX_SIGNAL_STRENGTH;
                }
            }
        } catch (SecurityException e) {
            e.printStackTrace();
        } catch (IllegalArgumentException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        } catch (InvocationTargetException e) {
            e.printStackTrace();
        }
        // Reflection code ends here
    }

}