-- This file defines Docker project commands.
-- All top level functions are available using `docker FUNCTION_NAME` from within project directory.
-- Default Docker commands can be overridden using identical names.

-- build images
function build()
	app.vote.build()
	app.result.build()
	app.worker.build()
end

function preRun()
	print("🐳 > build images...")
	build()
	print("🐳 > create networks...")
	utils.createNetworkIfNeeded(app.front_tier.name)
	utils.createNetworkIfNeeded(app.back_tier.name)
	print("🐳 > create volume...")
	utils.createVolumeIfNeeded(app.db_data.name)
end

-- run app
function up()
	preRun()

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()

	app.worker.run()
	app.result.run()
	app.vote.run()
end

-- dev python "vote" app
function devVote()
	preRun()

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()

	app.worker.run()
	app.result.run()
	app.vote.dev()
end

-- dev node "result" app
function devResult()
	preRun()

	print("🐳 > create containers...")
	app.redis.run()
	app.db.run()

	app.worker.run()
	app.vote.run()
	app.result.dev()
end

-- -- run app in dev mode
-- function dev()
-- 	preRun()
--
-- 	print("🐳 > create containers...")
-- 	app.redis.run()
-- 	app.db.run()
--
-- 	-- app.worker.dev()
-- 	-- app.result.dev()
-- 	app.vote.dev()
--
-- 	-- TODO: remove this
-- 	app.worker.run()
-- 	app.result.run()
-- end





app = {}
-- containers
app.vote = {}
app.result = {}
app.worker = {}
app.redis = {}
app.db = {}
-- volumes
app.db_data = {}
-- networks
app.front_tier = {}
app.back_tier = {}



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
-- app.worker.dev = function()
-- 	docker.cmd('run \
-- 	-ti \
-- 	--network ' .. app.back_tier.name .. ' \
-- 	' .. app.worker.image .. ' \
-- 	')
-- end



-- redis
app.redis.image = 'redis:alpine'
app.redis.alias = 'redis'
app.redis.run = function()
	docker.cmd('run \
	-d \
	--name ' .. app.redis.alias .. ' \
	--network ' .. app.back_tier.name .. ' \
	--network-alias ' .. app.redis.alias .. ' \
	-p 6379 \
	' .. app.redis.image)
end



-- db
app.db.image = 'postgres:9.4'
app.db.alias = 'db'
app.db.run = function()
	docker.cmd('run \
	-d \
	--name ' .. app.db.alias .. ' \
	--network ' .. app.back_tier.name .. ' \
	--network-alias ' .. app.db.alias .. ' \
	-v ' .. app.db_data.name .. ':/var/lib/postgresql/data \
	-p 6379 \
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
