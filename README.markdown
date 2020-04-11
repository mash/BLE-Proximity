BLE-Proximity
=============

BLE-Proximity implements contact tracing on iOS, to prevent COVID-19 transmissions.

After Apple and Google has announced their joint effort https://www.apple.com/covid19/contacttracing , I guess this repository will stay here for a record of, how usual iOS developers can provide similar functionality within what is allowed by public iOS APIs.

The basic idea was,

* An app on the phone generates a 8Byte random id, call it **userId**, and exchange it with the other users' apps running on their phones.
* Use Bluetooth Low Energy to exchange the userId between app users.
* The userId is only valid for X hours, the app regenerates a new userId after the period, and the history of userIds are stored in the owner's app.
* When you come close to another user that has the app installed, the app exchanges each others' latest userId and store the history of received userIds as **peerIds**.
* userIds and peerIds history are stored up to 4 weeks.
* When a person is diagnosed as COVID-19 positive, after consent and proper approval of medical personel,  the person's userId history is appended to a list that is served by web servers.
* Apps periodically fetchs the list and checks if the peerIds entry matches any entry in the positive list.

Privacy is ensured by,

* The userIds are random.
* Sent to someone when the phone running the app is close to another phone running the app, or over to servers on Internet only after you give consent.

Backend publishes 2 APIs.

1. Fetch Positive list

    Positive list entry consists of:
    - userIds of infected people

    This can be a static text file that gets updated when E-2 happens.

2. Append Positive list

    This is going to be called when a person was diagnosed as positive.  
    See E.

App maintains 2 history of userIds.

1. My ID history  
    This is the history of userIds that was generated on this app.

2. Peer ID history  
    This is the history of userIds that this app received from other apps.

App runs this logic.

A. Always:

A-1. Advertises a BLE service

    BLE service has a read characteristic that returns the app's userId.  
    BLE service has a write characteristic that lets other apps write their userIds into (*1)  
    Why not use iBeacon? (*2)

A-2. Scans for the same BLE service

B. When the app detects an BLE peripheral that advertises the service:

B-1. The app records:

    - The userId of the opponent from the read characteristic response, or from the write characteristic request  
    - Time  
    - Location of *this* phone  
    and does *not* send this to backend.

B-2. The app writes into the write characteristic that the BLE peripheral provides. (*1)

B-3. (Same as C-1)

C. When the app becomes active

C-1. If the app's own userId is older than X seconds, app generates a new userId in the phone

C-2. The app stores it's history of userIds that it generated

D. When the app receives a silent push notification

D-1. App fetches the Positive list from backend, and check if the history of userIds of this app is included in there

    Which means, that I have been near to an infected person.

D-2. If it was included

    TODO: Instruct user to stay at home and monitor yourself, be able to export your own location data to provide to medical personel after consent.

E. When the user knows that "I got infected" in a hospital

E-1. Tells the backend:

    These are the userIds history of myself, during this 4 weeks.
    TODO: How to make this information trustworthy, maybe doctor should sign it? 

E-2. Backend appends the Positive list with the provided information

E-3. Backend sends a silent push notification to all apps so that they can refresh the Positive list

---
Notes

*1 We want to maximize the communication opportunity between iOS and Android apps, including when both are operating in the background.

iOS has a limitation that it cannot advertise a service in the background in a way that is discoverable by Android phones.

> All service UUIDs contained in the value of the CBAdvertisementDataServiceUUIDsKey advertisement key are placed in a special “overflow” area; they can be discovered only by an iOS device that is explicitly scanning for them.

https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW9

Which means, Android apps cannot discover iOS apps that are advertising in the background. iOS apps have to discover Android apps.

And when iOS apps discover Android apps, iOS apps should write their userId into the write characteristic that Android app provides. This way both iOS and Android apps can know each other's userIds without involving a central server.

*2 Why not use iBeacon?
> Apps that use their underlying iOS device as an iBeacon must run in the foreground.

https://developer.apple.com/documentation/corelocation/turning_an_ios_device_into_an_ibeacon_device

We cannot expect people to run an app in foreground all the time when they get near to other people.
This has to run in the background.
