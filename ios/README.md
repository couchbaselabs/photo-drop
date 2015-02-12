PhotoDrop
=============

One of the cool features of Couchbase Lite is an ability to do P2P replication between two devices. `Couchbase Lite` is packaged with an extra component called `Couchbase Lite Listener` that allows your application to accept HTTP connections from other devices running Couchbase Lite and sync data with them. `PhotoDrop` application demonstrates how easily we can use those components to develop a P2P application.

`PhotoDrop` is a P2P photo sharing app similar to the iOS `AirDrop` feature that you can use to send photos across devices. The flow of the application is fairly simple. You select photos you want to share to your friend and open the QRCode scanner to scan the target endpoint that the selected photos will be sent to. On the other side, your friend opens the appliation, shows the QRCode and waits for you to scan and send the photos. The application screenshots can be seen below.

![screenshot] (https://cloud.githubusercontent.com/assets/801454/6072270/7774976c-ad54-11e4-9034-2045bccaf6be.png)

About the implementation, `PhotoDrop` uses a QRCode for peer discovery. The QRCode is used for advertising an adhoc endpoing URL that a sender can scan and send photos to. Basic Authentication is used for authenticating the sender. On the receiver side, we securely generate a one-time username & password, bundle them with the URL endpoint and encode them in a QRCode presented by the receiver to the sender. Once the sender scans the QRCode, the sender will have the user and password for authentication.

## Build & Run
1. Clone this repository.

 ```
 $ git clone https://github.com/couchbaselabs/photo-drop
 ```
2. Go into the ios folder.
3. Download [Couchbase Lite iOS][CBL_DOWNLOAD] and extract the zip file.
4. Copy `CouchbaseLite.framework` and `CouchbaseLiteListener.framework` into the `Frameworks` directory of this repo.
5. Open PhotoDrop.xcodeproj.
6. Click the Run button.

[CBL_DOWNLOAD]: http://www.couchbase.com/nosql-databases/downloads#Couchbase_Mobile
