# THIS IS INCUS INCANTATIONS

# Why ?

![](./charlie.webp)

## What ?

```
| '*' marks required arguments, all others are optional.
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
|
| cat <init-script> | malus <script>    
| ? Execute a script or gain a shell as a specific user 
| > Choose a RUNNING instance
|  > If a script was specified on stdin launch it 
|  > If a script was speciifed as the first argument launch it else run an interactive shell
|
| cat <init-script> | invokus <init-script> <name> <remote> 
| > Launches a new instance, prompts user to specify if it is a vm or not, then prompts for the image.
| > Optionally, one can specify a script in first position or in stdin to be run as a bootstrap.
| > If a script is also sent to STDIN both of them will run.
|
| cat <init-script> | linvokus <init-script> <name>
| ? wrapper around invokus, uses the local remote directly.
|
| startus           
| > Choose one or more STOPPED instances to start.
|
| delus             
| > Choose one or more STOPPED instances to delete.
|
| stopus            
| > Choose one or more RUNNING instance to stop.
|
| nukus             
| ? Nuke one or more instances
| > Choose one or more instance(s)
| > Forcefully delete the instances, will prompt for confirmation for each one
|
| projectus
| > Choose which project to switch to.
|
| aprofus          
| > Choose one or more profiles to add to an instance.
|
| deprofus          
| > Choose one or more profiles to delete. Does not handle checking if they are used.
|
| reprofus          
| > Choose an instance, then select the profiles to remove.
|
| publicus <*alias>
| > Choose one instance to publish, will prompt to stop if the instance is RUNNING.
|
| xeph <*display> 
| > Launch a Xephyr window using the given display number.

| xephus <*display> 
| ? Opens a Xephyr window and creates a profile to share its socket with an instance.
| > Launch a Xephyr window using the given display number.
| > Creates a dynamic profile to share the X socket for the Xephyr window with an instance.
| # The profile is saved in yaml format in `~/.dynamic_profiles/`
|
| copus
| ? Send or Fetch clipboard to/from a given instance
| > Choose a target action (fetch or send).
| > Choose a target instance.
| > If fetch was specified, `wl-paste` is piped to `xclip -i selection c` in the instance.
| > If send was specified, `xclip -o` is used by the instance to send its clipboard to `wl-copy`.
| # Uses wl-clip and xclip, very much a WIP and finnicky.
| # Of course this only works on wayland for now.
| 
| sendus
| ? Send one or more files to the `/shared` directory of an instance.
| > Choose files from the CWD.
| > Choose an recipient instance.
| > All files are sent to the `/shared` directory.
|
| transfus
| ? Allows transfers between instances by using pipes
| > Choose a source instance, 
| > Choose files to send from the `/shared` folder of the source.
| > Choose a recipient instance for the files,
| > All files are transferred using DD to the `/shared` directory of the recipient. 
| 
| creatus
| ? Launch scripts
| > Looks in the `~/.incantations.d/` folder, propose each existing folder inside to the user.
| > Once the choice is made, incantations navigates into the folder and executes the `create.sh` script and gives it all parameters.0
| # This is mostly added to let users add any custom scripts they wish to add to incantations.
|
| isus
| ? Create a Virtual-Machine from an ISO file.
| > Starts by selecting CPU/MEMORY and STORAGE SIZE.
| > Then picks an `.iso` file from CWD.
| > Starts the VM and grab to console (in case the user needs it)
| > Finally starts the VGA console.
|
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

## How ? 

```bash
[[ -d "${HOME}/.local/bin" ]] || mkdir -p "${HOME}/.local/bin"
git clone https://github.com/Ramoreik/incantations.git
cd incantations
mv incantations.sh "${HOME}/.local/bin/incantations"
echo ". ${HOME}/.local/bin/incantations" >> "${HOME}/.bashrc"
```

```bash
cat <script> |invokus
malus
```

## NOTE

This is all a WIP.
If you wish to contribute feel free.

