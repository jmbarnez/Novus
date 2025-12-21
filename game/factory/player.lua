local player = {}

function player.createPlayer(ecsWorld, ship)
  local e = ecsWorld:newEntity()
      :give("player")
      :give("pilot", ship)
      :give("player_progress", 1, 0, 100)
      :give("credits", 1000)

  return e
end

return player
