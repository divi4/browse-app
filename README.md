# flutter_base_project

Hey Wildlife team!

## The files

### .dart_tool, build and .flutter-plugins  
These files only appear during buildtime (when you execute the project). Sometimes you will 
face issues where Flutter is unable to delete these files to rebuild the project due to 
permission issues. Just delete these files manually if this occurs.  

### assets  
This is where Flutter expects assets such as images and videos to be placed so that the 
code can load them in when the asset class is called.  

### android and ios  
Build configurations specific to the android and iOS platforms, controls things such as the 
icon to load on the phone and to provide their respective app stores on what permissions the 
app requires.  

### lib  
Contains the dart files. This is where we build the actual screens of the app itself. Sub
directories have been organised by the userflow they pertain to.  

### auth/  
Contains all the screens and logic related to the authentication flow when the user first signs
in/signs-up to the app.  

### caretaker-view/  
Contains all screens and logic related to the caretaker order form userflow.  

### gatherer-view/  
Contains all screens and logic related to the gatherer request view and acceptance userflow.  

### landowner-view/  
Contains all screens and logic related to the landholder listing view and registration userflow.  

### education/  
Contains all screens and logic related to the searching of the browse catalog and plant 
identification. Will contain harvesting tutorials in future app iterations.  

### models/  
Contains the classes (known as model schema in MVC architecture) to enable converting 
JSON objects as received from the backend to objects that Flutter can work with.  

### personal/  
Contains the screen for user’s profile.  

### templates/  
Contains classes of widgets used multiple times in the app to simplify the code and enforce 
consistency. Such as the drawer widget that is found on nearly every screen and the browse 
listing panels found in the landholder and gatherer screens.  

### jsonParser.dart  
Contains the logic to convert JSON objects to Flutter objects and vice-versa.  

### main.dart  
The top level of the app. Contains all the routing definitions between the different screens of 
the app.  

### web  
Configuration files for web. File is needed to do quick tests in Chrome. 

### pubspec.yaml  
The last relevant file, dependencies need to be declared within here before they can be 
installed into the environment. This can be done easily without interacting with the actual file, 
just pass 

```batchfile
flutter pub add <package_name> 
```

to VScode’s terminal and restart VScode.  