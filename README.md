
# iapg (Interactive Photo Gallery)
**A system for interactive display of pictures on multiple screens/projectors controlled by tablets.**

##  Purpose
Suppose one or a few photography clubs will have an interactive picture exhibition with the following features:

- Pictures from the members should be displayed on screens/projectors.
- It should be possible to display a picture simultaneously on multiple screens/projectors.
- The viewing should be controlled by thumbnails on a tablet.
- When a thumbnail is clicked the corresponding picture should be displayed on the associated screens/projectors.
- When their has not been a thumbnail click for a while a slide-show should be run.
- It should be possible to run the exhibition in many rooms by using multiple tablets each with its own set of screens/projectors.    
- Many clubs should have the possibility to take part in the exhibition but they should be independent of each other.
- To be fair to the photographers all should have equal chance of getting there thumbnails placed on a specific spot on a tablet.
- *"club" should be used in a broad sense. It could be just pictures from a specific theme like street photography, birds, cars, etc.*


## Description
**This system has:**
- For the control a client-side rendered webpage with thumbnails runs a tablet.  
- A client-side rendered webpage will display the pictures on screens/projectors on demand from a tablet or a slideshow.
- A node.js JavaScript webserver application and a few scripts.


### The parts

- A Linux server will run the iapg SW and keep the directories for the pictures.
- If you just want a minimal setup use one tablet with "connected" screens/projectors and a "club-directory" with one sub-directory for each photographer for their pictures.
- You can use multiple tablets to request thumbnails from the same "club-directory" which on a click will show the corresponding picture on the related screens/projectors.
- If you want to run for many clubs each club will have a "club-directory", tablets and screens/projectors.


### Structure
- To make it simple you could use `/home/your-user` as the directory for the system. 
- Each club will have its own club-directory. In the range: `club-53001, club-53011, club-53021 ... club-53991`.  
- In the club-directory each photographer will have a sub-directory with the name of the photographer 
- Each photographer will store pictures in a directory like `./iapg-main/html/club-53001/Louis Daguerre/A picture worth showing.jpg`.
  - where `iapg-main` is the base directory of the system.
  - where `club-53001` is the directory for the club.
  - and "`Louis Daguerre`" is the sub-directory for the photographer.
- Because a signature picture of the photographer will be shown on the tablet a picture with the name of the photographer(+.jpg) must exist in his directory.
  - "`Louis Daguerre.jpg`".
- The signature picture will be shown as the first thumbnail in the block of the photographer but it is not meant to be displayed on the screens/projectors (and is thus not clickable)
- All other pictures will be displayed in ascending order.

*Each photographer will get a random position for the pictures on the tablet.*

### The principles for storing the pictures on the server.  
**Explained by examples**
  
With only one tablet (that is one club) each photographer will have a sub-directory in:
1. `./iapg-main/html/club-53001/`
   - `./Tor Jordsson/` (for member "Tor Jordsson")
   - `./Tölva Talvölva/`
  
With several clubs of photographers each club will have an own directory with sub-directories per photographer:
1. Club 1 `./iapg-main/html/club-53001/`
   - `./Freja Njordsdottir/` 
   - `./Balder Friggsson/`
2. Club 2 `./iapg-main/html/club-53011/`
   - `./Natt Norvesdottir/` 
3. Club 3 `./iapg-main/html/club-53021/`
   - `./Oden Skaldemjöd/`

***
## HW and SW
node.js is used as the web-server.

The system is tested on Windows10 with Debian in an Oracle VM and on a Raspberry PI4 with raspian.

You can try the system in a computer with  node.js and use one browser as the  "tablet" and another one as the screen/projector.

### Installation on Debian/Raspian
**To install the Node.js JavaScript runtime environment**  
`sudo apt-get install node.js`

**To install the iapg kit**  
Firstly go to `/home/your-user`

Then browse to https://github.com/pg-andersson/iapg and click on "<>Code" and then "Download ZIP"  
Github will create `iapg-main.zip` which will be copied to Downloads.  

Then `unzip` which will create the directory `iapg-main` and extract the files to it.  
`unzip Downloads/iapg-main.zip`   (***Important it is your-user***)  

**Finally install the dependencies**  
Go to the just created directory `/home/your-user/iapg-main` and run:  
`npm install`   (***Important it is your-user***) 

### Configuration
System parameters are stored in `./iapg-main/etc/iapg.conf`.  
The two most important are:

- `waittime_before_slideshow_starts = 60` After 60 seconds display of a picture a slideshow will begin or resume until a thumbnail is pressed.
- `pict_displaytime_slideshow = 10` During a slideshow a picture is displayed for 10 seconds.
***
## Usage
### Three scenarios are presented here

1. A club will have a small exhibition.   
The club will be called club-53001 and will have one tablet and at least one screen.
2. A club will use three rooms to show the same pictures but the showings must be independent of each other.  
The club will be called club-53011 and will have three tablets and a lot of screens.
3. Two clubs will have an exhibition together.
   1. One club will be called club-53021.
   2. The other club will be club-53031.

### The server
**To start the system run in ./iapg-main as your-user:**

1. `bash iapg_start.sh club-53001:1` (Club-53001 will use the directory club-53001 and have one (:1) tablet)
2. `bash iapg_start.sh club-53011:3` (Club-53011 will use the directory club-53011 and have three (:3) tablets)
3. `bash iapg_start.sh club-53021:1 club-53031:1`
	- club-53021 will use the directory club-53021 and have one (:1) tablet
	- club-53031 will use the directory club-53031 and have one (:1) tablet

*If you will have a "megashow" (e.g. some theme groups) it is more convenient to save the parameters in `clublist.conf` as shown here:*  
club-53021:1  # Street photography group  
club-53031:1  # Bird watching  
club-53041:1  # Architectural  
club-53051:1  # Vanitas   
club-53061:1  # Black and White  
*and then just run: `bash iapg_start.sh`*  

*You can store as many "clubs" as you like on the server. Only those in the clublist.conf (or named as parameters) will be started.*

*If you want the name of a club to be shown on the screens/projectors you should add it in a file as shown here:*  
`./iapg-main/html/club-53001/club_name.txt`.  
Midgård picture club

### The tablets

1. The only tablet will show the thumbnails for club-53001.  
`open http://ip-of-iapg-server:53001/index.html`
2. All three tablets will show the thumbnails for club-53011.
   1. `open http://ip-of-iapg-server:53011/index.html` (Each tablet requires an own "port number")
   2. `open http://ip-of-iapg-server:53012/index.html`	
   3. `open http://ip-of-iapg-server:53013/index.html` 
3. Each of the clubs will have its own tablet.
   1. `open http://ip-of-iapg-server:53021/index.html` (Thumbnails for club-53021)
   2. `open http://ip-of-iapg-server:53031/index.html` (For club-53031)
   
*When a thumbnail page is loaded/reloaded the block of pictures of the photographers will get new random positions.*

### The screens/projectors

1. To show pictures on screens on behalf of the only tablet for club-53001.
   1. `open http://ip-of-iapg-server:53001/show.html` (Open this on every screen the club has)
2. To show pictures on screens on behalf of the three tablets for club-53011.
   1. `open http://ip-of-iapg-server:53011/show.html` (Open this for screens that shall show pictures for clicks on the first tablet)
   2. `open http://ip-of-iapg-server:53012/show.html` (For the second tablet)
   3. `open http://ip-of-iapg-server:53013/show.html` (The third tablet)
3. To show pictures on behalf of respective club's tablet.
   1. `open http://ip-of-iapg-server:53021/show.html` (Open this on every screen club-53021 has)
   2. `open http://ip-of-iapg-server:53031/show.html` (Club-53031)
		
*You must initially request the show.html page on each screen if you do not have them set up as "Chromium-kiosks" with auto-start.*

The system starts with an independent slideshow per tablet. Such a slideshow will run until it is interrupted by a thumbnail request.

**To stop the exhibitions**
 
Run the following command to stop them:  
`bash iapg_stop.sh` 
***
##  Statistics
Access statistics are collected in realtime in json-files and CSV-files will be created when the system is stopped.  
Stored in `./iapg-main/var/stat/`

You can run the following command to create the CSV-files right away:  
`bash click_stats_to_csv.sh`

#### Daily statistics with number of clicks per picture. Both thumbnail clicks and slideshow clicks.

- 2024-01-21_clicks_53001.json 
- 2024-01-21_clicks_53001.csv
- 2024-01-21_clicks_53002.json 
- 2024-01-21_clicks_53002.csv
- 2024-01-21_click_summary.csv  (Accumulated for all tablets. One per day)

#### Statistics collected each time the thumbnails are reloaded. Per tablet.

The statistics are presented in the order the pictures had on each tablet. 
By reloading the tablets thumbnails in controlled intervals it could by possible to see if a certain position on the tablet is preferable.

- clicks_53001_2024-01-20_153847.json (Statistics for the first tablet)
- clicks_53001_2024-01-20_153847.csv
- clicks_53002_2024-01-20_153848.json (The second tablet)
- clicks_53002_2024-01-20_153848.csv
