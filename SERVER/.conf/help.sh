# --------------------------------------------------------------------------------
# ./SERVER-MANAGER.sh --help
# --------------------------------------------------------------------------------
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    clear
    echo -e "\n\e[1;37m=====================================================================================\n"
    echo -e "                          \e[1;33mSERVER MANAGER - USAGE GUIDE\e[0m"
    echo -e "\n\e[1;37m=====================================================================================\e[0m"

    echo -e "\n\e[1;36mUsage:\e[0m \e[1;32mzsh .SERVER-MANAGER.sh [option] [server-type] [server-name]\e[0m"
    echo -e "  \e[1;30mExample:\e[0m \e[1;37mzsh .SERVER-MANAGER.sh --start-server FORGE MyServerName\e[0m"

    echo -e "\n\e[1;36mInteractive Mode:\e[0m"
    echo -e "  Run with no arguments to use interactive menu: \e[1;32mzsh .SERVER-MANAGER.sh\e[0m"

    echo -e "\n\e[1;36mAvailable Options:\e[0m"
    echo -e "  \e[1;33m--help\e[0m               Show this help message and exit"
    echo -e "  \e[1;33m--start-server\e[0m       Start the specified server"
    echo -e "  \e[1;33m--stop-server\e[0m        Stop the specified server"
    echo -e "  \e[1;33m--restart-server\e[0m     Restart the specified server"
    echo -e "  \e[1;33m--create-server\e[0m      Launch guided creation for a new server"
    echo -e "  \e[1;33m--delete-server\e[0m      Remove a server folder (requires confirmation)"
    echo -e "  \e[1;33m--archive-server\e[0m    Archieves a server folder (*.zip)"
    echo -e "  \e[1;33m--status\e[0m             Check if a server is ONLINE or OFFLINE"
    echo -e "  \e[1;33m--status-all\e[0m         Show status of all servers"
    echo -e "  \e[1;33m--list\e[0m               List all registered servers by type"

    echo -e "\n\e[1;36mArguments:\e[0m"
    echo -e "  \e[1;37m[server-type]\e[0m        Type of server: VANILLA, FORGE, MAP/PARKOUR, MAP/ESCAPE, MAP/OTHER"
    echo -e "  \e[1;37m[server-name]\e[0m        Name of the server folder"
    echo -e "  \e[1;37m[minecraft-version]\e[0m  Minecraft version to use"
    echo -e "  \e[1;37m[forge-version]\e[0m      Forge version (only for FORGE type, optional)"

    echo -e "\n\e[1;36mExamples:\e[0m"

    echo -e "  \e[0;30m[Start server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --start-server FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --start-server <server-type> <server-name>\e[0m"
    
    echo -e "  \e[0;30m[Stop server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --stop-server VANILLA TestServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --stop-server <server-type> <server-name>\e[0m"
    
    echo -e "  \e[0;30m[Restart server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --restart-server FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --restart-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Create a new server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --create-server FORGE MyServer 1.20.1 47.2.0\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --create-server <server-type> <server-name> <minecraft-version>  [<forge-version> --optional]\e[0m"
    
    echo -e "  \e[0;30m[Delete server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --delete-server VANILLA OldServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --delete-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Archieve server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --archive-server VANILLA OldServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --archive-server <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Check status of a specific server]\e[0m"
    echo -e "  \e[1;37mzsh .SERVER-MANAGER.sh --status FORGE MyServer\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --status <server-type> <server-name>\e[0m"

    echo -e "  \e[0;30m[Show statuses of all servers]\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --status-all\e[0m"

    echo -e "  \e[0;30m[Show all known servers by type]\e[0m"
    echo -e "  \e[1;33mzsh .SERVER-MANAGER.sh --list\e[0m"

    echo -e "\n\e[1;36mExpected Directory Layout:\e[0m"
    echo -e "  \e[1;33m/home/Minecraft/SERVERS/[TYPE]/[NAME]/\e[0m"
    echo -e "  \e[1;33m/home/Minecraft/SERVER/\e[0m (configs, logs, this script)"

    echo -e "\n\e[1;36mRequirements:\e[0m"
    echo -e "  \e[1;37m• tmux\e[0m"
    echo -e "  \e[1;37m• Java 8 / 17 / 21\e[0m (via update-alternatives)"
    echo -e "  \e[1;37m• curl, jq, unzip, sudo, PHP\e[0m"

    echo -e "\n\e[1;37m=====================================================================================\e[0m"
    exit 0
fi