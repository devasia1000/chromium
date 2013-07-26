This lightly modified version of Chromium was developed by Devasia Manuel for MIT's Alfalfa project. The purpose of this version of Chromium is to measure the performance of HTML5 video playback over unreliable cellular links. Unreliable Cellular links are emulated by 'Cellsim' - a trace driven network a trace driven network emulator that replays the arrival/departure of packets to the host with the help of actual cellular network trace files collected from around Boston. 'Cellsim' was developed by Keith Winstein and Anirudh Sivaraman but has been forked and modified by Devasia Manuel to make it work well with Chromium. Cellsim is run within Mininet to allow the entire setup to work on a single machine. Cellsim and Chromium work together to automatically play a YouTube video, generate real time graphs of stalls and video resolutions and print log files to ~/Desktop/log.

To setup Chromium and Cellsim correctly, please follow the instructions:

1) First, you'll need to get your hands on Google's repo cloning tool.

	- Navigate to your Desktop and run: 'git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git to fetch 'depot_tools'
	- Add depot_tools to your PATH:
		1.$ export PATH="$PATH":`pwd`/depot_tools
		2.You may want to add this to your .bashrc file or your shell's equivalent so that you don't need to reset your $PATH manually each time you open a new shell.
	-  Run this command: 'git config --global core.deltaBaseCacheLimit 2G'

2) Next, you'll need to get your hands on my (Devasia's) version of Chromium  by cloning my Github repo. 
	
	- Run this command: 

		'gclient config --spec 'solutions = [{u'"'"'managed'"'"': True,
		u'"'"'name'"'"': u'"'"'src'"'"', u'"'"'url'"'"':
		u'"'"'https://github.com/devasia1000/chromium.git'"'"',
		u'"'"'custom_deps'"'"': {}, u'"'"'deps_file'"'"':
		u'"'"'.DEPS.git'"'"', u'"'"'safesync_url'"'"': u'"'"''"'"'}]'
	
	- Download Chromium's source code from my repo: 'gclient sync' - will take 30 mins or more
	- Change directory to the downloaded git repo and switch to the 'chromium_seek_test' branch
	- Run 'build_chromium.sh' - this will take about 30mins or more 
	- Rename the Chromium directory to 'src'make sure 'src' is located in ~/Desktop/

3)   Congratulations! You've got Chromium setup correctly. To setup Cellsim, follow the instructions:

	- change directory to ~
	- run 'git clone https://github.com/devasia1000/cellsim'
	- Compile Cellsim by running 'make'

4) To play a video, run: 'sudo python start_cellsim_with_internet.py {username} {uplinkTrace} {downlinkTrace} {lossRate} {youtubeVideoLink}' in the Cellsim directory. Cellsim should start Mininet and Chromium automatically and print log files to ~/Desktop/log

If you run into any trouble with the code, please don't hesitate to contact me at devasia@mit.edu
