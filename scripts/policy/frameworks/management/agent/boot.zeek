##! The cluster agent boot logic runs in Zeek's supervisor and instructs it to
##! launch a Management agent process. The agent's main logic resides in main.zeek,
##! similarly to other frameworks. The new process will execute that script.
##!
##! If the current process is not the Zeek supervisor, this does nothing.

@load base/utils/paths

@load ./config

# The agent needs the supervisor to listen for node management requests.  We
# need to tell it to do so, and we need to do so here, in the agent
# bootstrapping code, so the redef applies prior to the fork of the agent
# process itself.
redef SupervisorControl::enable_listen = T;

event zeek_init()
	{
	if ( ! Supervisor::is_supervisor() )
		return;

	local epi = Management::Agent::endpoint_info();
	local sn = Supervisor::NodeConfig($name=epi$id, $bare_mode=T,
		$scripts=vector("policy/frameworks/management/agent/main.zeek"));

	# Establish the agent's working directory. If one is configured
	# explicitly, use as-is if absolute. Otherwise, append it to the state
	# path. Without an explicit directory, fall back to the agent name.
	local statedir = build_path(Management::get_state_dir(), "nodes");

	if ( ! mkdir(statedir) )
		print(fmt("warning: could not create state dir '%s'", statedir));

	if ( Management::Agent::directory != "" )
		sn$directory = build_path(statedir, Management::Agent::directory);
	else
		sn$directory = build_path(statedir, Management::Agent::get_name());

	if ( ! mkdir(sn$directory) )
		print(fmt("warning: could not create agent state dir '%s'", sn$directory));

	if ( Management::Agent::stdout_file != "" )
		sn$stdout_file = Management::Agent::stdout_file;
	if ( Management::Agent::stderr_file != "" )
		sn$stderr_file = Management::Agent::stderr_file;

	# This helps identify Management framework nodes reliably.
	sn$env["ZEEK_MANAGEMENT_NODE"] = "AGENT";

	local res = Supervisor::create(sn);

	if ( res != "" )
		{
		print(fmt("error: supervisor could not create agent node: %s", res));
		exit(1);
		}
	}
