-- This file defines Docker project commands.
-- All top level functions are available using `docker FUNCTION_NAME` from within project directory.
-- Default Docker commands can be overridden using identical names.


-- build images
function build()
	app.vote.build()
	app.result.build()
	app.worker.build()
end

-- build and run app
function up()
	print("🐳 > building images...")
	build()

	print("🐳 > creating networks...")
	utils.createNetworkIfNeeded(app.front_tier.name)
	utils.createNetworkIfNeeded(app.back_tier.name)

	print("🐳 > creating volume...")
	utils.createVolumeIfNeeded(app.db_data.name)

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()
	app.worker.run()
	app.result.run()
	app.vote.run()
end

-- dev python "vote" program
function dev_vote()
	print("🐳 > building images...")
	build()

	print("🐳 > creating networks...")
	utils.createNetworkIfNeeded(app.front_tier.name)
	utils.createNetworkIfNeeded(app.back_tier.name)

	print("🐳 > creating volume...")
	utils.createVolumeIfNeeded(app.db_data.name)

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()
	app.worker.run()
	app.result.run()
	app.vote.dev()
end

-- dev node "result" program
function dev_result()
	print("🐳 > building images...")
	build()

	print("🐳 > creating networks...")
	utils.createNetworkIfNeeded(app.front_tier.name)
	utils.createNetworkIfNeeded(app.back_tier.name)

	print("🐳 > creating volume...")
	utils.createVolumeIfNeeded(app.db_data.name)

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()
	app.worker.run()
	app.vote.run()
	app.result.dev()
end

-- dev .NET "worker" program
function dev_worker()
	print("🐳 > building images...")
	build()

	print("🐳 > creating networks...")
	utils.createNetworkIfNeeded(app.front_tier.name)
	utils.createNetworkIfNeeded(app.back_tier.name)

	print("🐳 > creating volume...")
	utils.createVolumeIfNeeded(app.db_data.name)

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()
	app.vote.run()
	app.result.run()
	app.worker.dev()
end



app = {}
-- networks
app.front_tier = {}
app.back_tier = {}
-- volumes
app.db_data = {}
-- containers
app.vote = {}
app.result = {}
app.worker = {}
app.redis = {}
app.db = {}



-- vote
app.vote.image = docker.project.name .. '-vote'
app.vote.context = 'vote'
app.vote.dockerfile = 'vote/Dockerfile'
app.vote.build = function()
	docker.cmd('build \
	-t ' .. app.vote.image .. ' \
	-f ' .. app.vote.dockerfile .. ' \
	' .. app.vote.context)
end
app.vote.run = function()
	docker.cmd('run \
	-d \
	--network ' .. app.front_tier.name .. ' \
	--network ' .. app.back_tier.name .. ' \
	-p 5000:80 \
	' .. app.vote.image .. ' \
	python app.py')
end
app.vote.dev = function()
	docker.cmd('run \
	-ti \
	-v ' .. docker.project.root .. '/vote:/app \
	--network ' .. app.front_tier.name .. ' \
	--network ' .. app.back_tier.name .. ' \
	-p 5000:80 \
	' .. app.vote.image .. ' \
	ash')
end
app.vote.service = {}
app.vote.service.update = function()
	local services = docker.service.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, service in ipairs(services) do
		if service.image == app.vote.image then
			docker.cmd('service update \
			--replicas 1 \
			--update-delay 10s \
			--force \
			' .. service.id)
			return
		end
	end
	docker.cmd('service create \
	--replicas 1 \
	-p 5000:80 \
	--network=' .. app.front_tier.name .. ' \
	--network=' .. app.back_tier.name .. ' \
	' .. app.vote.image)
end



-- result
app.result.image = docker.project.name .. '-result'
app.result.context = 'result'
app.result.dockerfile = 'result/Dockerfile'
app.result.build = function()
	docker.cmd('build \
	-t ' .. app.result.image .. ' \
	-f ' .. app.result.dockerfile .. ' \
	' .. app.result.context)
end
app.result.run = function()
	docker.cmd('run \
	-d \
	--network ' .. app.front_tier.name .. ' \
	--network ' .. app.back_tier.name .. ' \
	-p 5001:80 \
	-p 5858:5858 \
	' .. app.result.image .. ' \
	nodemon')
end
app.result.dev = function()
	docker.cmd('run \
	-ti \
	-v ' .. docker.project.root .. '/result:/app \
	--network ' .. app.front_tier.name .. ' \
	--network ' .. app.back_tier.name .. ' \
	-p 5001:80 \
	-p 5858:5858 \
	' .. app.result.image .. ' \
	bash')
end
app.result.service = {}
app.result.service.update = function()
	local services = docker.service.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, service in ipairs(services) do
		if service.image == app.result.image then
			docker.cmd('service update --replicas 1 --update-delay 10s --force ' .. service.id)
			return
		end
	end
	docker.cmd('service create \
	--replicas 1 \
	-p 5001:80 \
	-p 5858:5858 \
	--network=' .. app.front_tier.name .. ' \
	--network=' .. app.back_tier.name .. ' \
	' .. app.result.image)
end



-- worker
app.worker.image = docker.project.name .. '-worker'
app.worker.context = 'worker'
app.worker.dockerfile = 'worker/Dockerfile'
app.worker.build = function()
	docker.cmd('build \
	-t ' .. app.worker.image .. ' \
	-f ' .. app.worker.dockerfile .. ' \
	' .. app.worker.context)
end
app.worker.run = function()
	docker.cmd('run \
	-d \
	--network ' .. app.back_tier.name .. ' \
	' .. app.worker.image)
end
app.worker.dev = function()
	docker.cmd('run \
	-ti \
	-v ' .. docker.project.root .. '/worker/src/Worker:/code/src/Worker \
	--network ' .. app.back_tier.name .. ' \
	' .. app.worker.image .. ' \
	bash -c "cd src/Worker && bash"')
end
app.worker.service = {}
app.worker.service.update = function()
	local services = docker.service.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, service in ipairs(services) do
		if service.image == app.worker.image then
			docker.cmd('service update --replicas 1 --update-delay 10s --force ' .. service.id)
			return
		end
	end
	docker.cmd('service create \
	--replicas 1 \
	--network ' .. app.back_tier.name .. ' \
	' .. app.worker.image)
end



-- redis
app.redis.image = 'redis:alpine'
app.redis.alias = 'redis'
app.redis.run = function()
	docker.cmd('run \
	-d \
	--network ' .. app.back_tier.name .. ' \
	--network-alias ' .. app.redis.alias .. ' \
	-p 6379 \
	' .. app.redis.image)
end
app.redis.service = {}
app.redis.service.update = function()
	local services = docker.service.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, service in ipairs(services) do
		if service.name == app.redis.alias then
			docker.cmd('service update ' .. service.id)
			return
		end
	end
	docker.cmd('service create \
	--mode global \
	--network ' .. app.back_tier.name .. ' \
	--name ' .. app.redis.alias .. ' \
	' .. app.redis.image)
end



-- db
app.db.image = 'postgres:9.4'
app.db.alias = 'db'
app.db.run = function()
	docker.cmd('run \
	-d \
	--network ' .. app.back_tier.name .. ' \
	--network-alias ' .. app.db.alias .. ' \
	-v ' .. app.db_data.name .. ':/var/lib/postgresql/data \
	-p 6379 \
	' .. app.db.image)
end
app.db.service = {}
app.db.service.update = function()
	local services = docker.service.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, service in ipairs(services) do
		if service.name == app.db.alias then
			docker.cmd('service update ' .. service.id)
			return
		end
	end
	docker.cmd('service create \
	--mode global \
	--network ' .. app.back_tier.name .. ' \
	--name ' .. app.db.alias .. ' \
	--mount src=' .. app.db_data.name .. ',dst=/var/lib/postgresql/data \
	' .. app.db.image)
end


-- volume
app.db_data.name = docker.project.name .. '-volume-db_data'



-- front_tier network
app.front_tier.name = docker.project.name .. '-network-front_tier'


-- back_tier network
app.back_tier.name = docker.project.name .. '-network-back_tier'



-- Lists project containers
function ps(args)
	local argsStr = utils.join(args, " ")
	docker.cmd('ps ' .. argsStr .. ' --filter label=docker.project.id:' .. docker.project.id)
end

-- Stops running project containers
function stop(args)
	-- retrieve command args
	local argsStr = utils.join(args, " ")
	-- stop project containers
	local containers = docker.container.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, container in ipairs(containers) do
		docker.cmd('stop ' .. argsStr .. ' ' .. container.name)
	end
end

-- Removes project containers, images, volumes & networks
function clean()
	-- stop project containers
	stop()
	-- remove project containers
	local containers = docker.container.list('-a --filter label=docker.project.id:' .. docker.project.id)
	for i, container in ipairs(containers) do
		docker.cmd('rm ' .. container.name)
	end
	-- remove project images
	local images = docker.image.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, image in ipairs(images) do
		docker.cmd('rmi ' .. image.id)
	end
	-- remove project volumes
	local volumes = docker.volume.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, volume in ipairs(volumes) do
		docker.cmd('volume rm ' .. volume.name)
	end
	-- remove project networks
	local networks = docker.network.list('--filter label=docker.project.id:' .. docker.project.id)
	for i, network in ipairs(networks) do
		docker.cmd('network rm ' .. network.id)
	end
end

----------------
-- UTILS
----------------

utils = {}

-- returns a string combining strings from  string array in parameter
-- an optional string separator can be provided.
utils.join = function(arr, sep)
	str = ""
	if sep == nil then
		sep = ""
	end
	if arr ~= nil then
		for i,v in ipairs(arr) do
			if str == "" then
				str = v
			else
				str = str .. sep ..  v
			end
		end
	end
	return str
end

-- creates a network if it does not exist
utils.createNetworkIfNeeded = function(name)
	local networks = docker.network.list('--filter label=docker.project.id:' .. docker.project.id)
	local found = false
	for i, network in ipairs(networks) do
		if network.name == name then
			found = true
		end
	end
	if found == false then
		docker.cmd('network create ' .. name)
	end
end

-- creates an OVERLAY network if it does not exist
utils.createOverlayNetworkIfNeeded = function(name)
	local networks = docker.network.list('--filter label=docker.project.id:' .. docker.project.id)
	local found = false
	for i, network in ipairs(networks) do
		if network.name == name then
			found = true
		end
	end
	if found == false then
		docker.cmd('network create -d overlay ' .. name)
	end
end

-- creates a volume if it does not exist
utils.createVolumeIfNeeded = function(name)
	local volumes = docker.volume.list('--filter label=docker.project.id:' .. docker.project.id)
	local found = false
	for i, volume in ipairs(volumes) do
		if volume.name == name then
			found = true
		end
	end
	if found == false then
		docker.cmd('volume create ' .. name)
	end
end



----------------
-- DOCKER TUNNEL
----------------

tunnel = {}
tunnel.originalDockerHost = nil

-- establishes ssh tunnel to target Docker host and returns
-- containers acting as proxy
tunnel.start = function(addr, privateKeyPath)
	-- privateKeyPath default value
	if privateKeyPath == nil or privateKeyPath == '' then
		privateKeyPath = os.home() .. '/.ssh/id_rsa'
	end

	if tunnel.originalDockerHost == nil then
		tunnel.originalDockerHost = os.getEnv("DOCKER_HOST")
	end
	os.setEnv("DOCKER_HOST", tunnel.originalDockerHost)

	print('establishing tunnel to ' .. addr)

	--look for existing tunnel for the same address
	local containers = docker.container.list('--filter label=tunnel:' .. addr .. ' ' ..
		'--filter label=docker.project.id:' .. docker.project.id)

	if #containers == 0 then
		docker.cmd('run -d -v ' .. privateKeyPath .. ':/ssh_id ' ..
			'-p 127.0.0.1::2375 --label tunnel:' .. addr .. ' ' ..
			'aduermael/docker-tunnel ' .. addr .. ' -i /ssh_id -p')

		containers = docker.container.list('--filter label=tunnel:' .. addr .. ' ' ..
			'--filter label=docker.project.id:' .. docker.project.id)
	end


	local tunnelContainer = nil
	-- public port that's been allocated
	local publicPort = 0

	local found = false
	for i,container in ipairs(containers) do
		for i,port in ipairs(container.ports) do
			if port.private == 2375 then
				tunnelContainer = container
				publicPort = port.public
				found = true
				break
			end
		end
		if found then break end
	end

	if found == false then
		error("can't find tunnel container")
	end

	-- determine tunnel container ip to test if service is ready
	local ip = ""
	local out, err = docker.silentCmd('inspect ' .. tunnelContainer.id)
	arr = json.decode(out)
	if #arr == 1 then
		local tbl = arr[1]
		ip = tbl.NetworkSettings.Networks.bridge.IPAddress
	end

	print('waiting for proxy (tcp://127.0.0.1:' .. publicPort .. ')')

	-- check to see if tunnel is ready
	local success, err = pcall(docker.cmd, 'run --rm aduermael/wait-for-service ' .. ip .. ':2375 6 0.5')
	if success == false then
		tunnel.stop(tunnelContainer)
		error(err)
	end

	os.setEnv("DOCKER_HOST", 'tcp://127.0.0.1:' .. publicPort)

	return tunnelContainer
end

-- stops docker tunnel container
tunnel.stop = function(container)
	os.setEnv("DOCKER_HOST", tunnel.originalDockerHost)
	docker.silentCmd('rm -f ' .. container.id)
	print("tunnel removed")
end



----------------
-- OPS TERRITORY
----------------

-- deploy in production
function deploy()
	-- connect to production Swarm
	local privateKeyPath = os.home() .. '/.ssh/id_rsa_srv'
	local tunnel_container = tunnel.start('198.199.107.26', privateKeyPath)

	print("🐳 > build images...")
	build()
	print("🐳 > create networks...")
	utils.createOverlayNetworkIfNeeded(app.front_tier.name)
	utils.createOverlayNetworkIfNeeded(app.back_tier.name)
	print("🐳 > create volume...")
	utils.createVolumeIfNeeded(app.db_data.name)

	app.redis.service.update()
	app.db.service.update()

	app.vote.service.update()
	app.result.service.update()
	app.worker.service.update()

	tunnel.stop(tunnel_container)
end
