# THIS IS INCUS INCANTATIONS

# Why ?

![](./charlie.webp)

## What ?

```
| '*' marks required arguments, all others are optional.
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
|
| malus <script>    
| > Choose a RUNNING instance and launch a script or interactive shell.
|
| nukus             
| > Choose one or more instances to forcefully delete, will prompt for confirmation for each one.
|
| cat <init-script> | invokus <init-script> <name> <remote> 
| > Launches a new instance, prompts user to specify if it is a vm or not, then prompts for the image.
| > Optionally, one can specify a script in first position or in stdin to be run as a bootstrap.
| > If a script is also sent to STDIN both of them will run.
|
| cat <init-script> | linvokus <init-script> <name>
| > wrapper around invokus, uses the local remote directly.
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
| > Launch a Xephyr window.
| 
| sendus
| > Choose a file from the CWD, then an instance to send it to.
| > All files are sent to the /shared directory.
|
| transfus
| > Choose a source instance, then files to send from the /shared folder of that instance.
| > Afterwards, choose a destintation instance for the files, they will be transferred using DD to the /shared directory. 
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

