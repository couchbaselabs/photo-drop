# PhotoDrop Android

![screenshot](http://cl.ly/image/2O0v3T1f0r3g/Frame.png)

## Build & Run

Run the app on a device. The Couchbase Lite Listener exposes a url and it's harder to interface with the Listener using
Android emulators. It's recommended to run the app an Android device and iOS simulator to test PhotoDrop.

1. Clone this repository.

 ```
 $ git clone https://github.com/couchbaselabs/photo-drop
 ```
2. Go into the android folder.
3. The Couchbase Lite and Couchbase Lite Listener dependencies are imported through git submodules:

 ```
 $ git submodule init
 $ git submodule update
 ```
4. Open `build.gradle` in Android Studio.
5. Click the Run button.

Feel free to [open an issue](https://github.com/couchbaselabs/photo-drop/issues/new) to report bugs and improve PhotoDrop Android.

## Running PhotoDrop with Android simulators

Stock Android emulators can access the host machine on the IP `http://10.0.2.2`. For Genymotion emulators it's on
`http://10.0.3.2`. This is often useful to have your Android app running in the emulator and sync with Sync Gateway
running locally on your machine.

In the case of PhotoDrop, we need to access the Couchbase Lite Listener from the host machine.

Use the ADB forward command to do so. If the Listener is running on port `5432`:

 ```
 $ adb forward tcp:5432 tcp:5432
 ```

Now open `http://localhost:5432/` in a Web browser on your host machine, you should see the Couchbase Lite Welcome 
message.

You will also have to change the hostname of the url encoded in `ReceiverActivity.java` to be the one of your host 
machine.