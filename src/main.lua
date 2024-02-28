push = require 'push'
Class = require 'class'

require 'Paddle'
require 'Ball'


WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243


function love.load()
    love.graphics.setDefaultFilter('nearest','nearest')

    love.window.setTitle('Pong')

    math.randomseed(os.time())

    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf',16)
    scoreFont = love.graphics.newFont('font.ttf', 32)

    love.graphics.setFont(smallFont)

    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
    }

    push:setupScreen(VIRTUAL_WIDTH,VIRTUAL_HEIGHT,WINDOW_WIDTH,WINDOW_HEIGHT,{
        fullscreen = false,
        resizable = true,
        vsync = true,
        canvas = false
    })
    player1 = Paddle(10, 30, 5, 20)
    player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)

    -- place a ball in the middle of the screen
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 4, 4)

    -- initialize score variables
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- player who won the game; not set to a proper value until we reach
    -- that state in the game
    winningPlayer = 0

    -- At the start the player will select one of the paddles and so will the CPU
    playerPaddle = {}
    cpuPaddle = {}

    -- At all time the cpu paddle will have a y position it have to move to 
    cpuFinalYPosition = nil

    PADDLE_SPEED = 200
    BALL_ACCELERATION = 3
    NUMBER_OF_PLAYERS = 2
    VICTORY_SCORE = 10

    -- the state of our game; can be any of the following:
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    gameState = 'startMenu'
    menuState = 'modifyPaddleSpd'
end

function love.resize(w, h)
    push:resize(w,h)
end

function love.update(dt)
    if gameState == 'startMenu' then
        if menuState == 'modifyPaddleSpd' then
            if love.keyboard.isDown('up') then
                if PADDLE_SPEED + 1 > 999 then
                    PADDLE_SPEED = 1
                end
                PADDLE_SPEED = PADDLE_SPEED + 1
            elseif love.keyboard.isDown('down') then
                if PADDLE_SPEED - 1 < 1 then
                    PADDLE_SPEED = 999
                end
                PADDLE_SPEED = PADDLE_SPEED - 1
            end
        elseif menuState == 'modifyBallAccel' then
            if love.keyboard.isDown('up') then
                if BALL_ACCELERATION + 1 > 99 then
                    BALL_ACCELERATION = 1
                end
                BALL_ACCELERATION = BALL_ACCELERATION + 1
            elseif love.keyboard.isDown('down') then
                if BALL_ACCELERATION - 1 < 1 then
                    BALL_ACCELERATION = 99
                end
                BALL_ACCELERATION = BALL_ACCELERATION - 1
            end
        elseif menuState ==  'modifyVictoryScore' then
            if love.keyboard.isDown('up') then
                if VICTORY_SCORE + 1 > 99 then
                    VICTORY_SCORE = 1
                end
                VICTORY_SCORE = VICTORY_SCORE + 1
            elseif love.keyboard.isDown('down') then
                if VICTORY_SCORE - 1 < 1 then
                    VICTORY_SCORE = 99
                end
                VICTORY_SCORE = VICTORY_SCORE - 1
            end
        elseif menuState == 'modifyNumOfPlayers' then
            if love.keyboard.isDown('1') then
                NUMBER_OF_PLAYERS = 1
                menuState = 'selectPlayer'
            elseif love.keyboard.isDown('2') then
                NUMBER_OF_PLAYERS = 2
                menuState = 'confirm'
            end
        elseif menuState == 'selectPlayer' then
            if love.keyboard.isDown('1')  then
                playerPaddle = player1
                cpuPaddle = player2
                menuState = 'confirm'
            elseif love.keyboard.isDown('2') then
                playerPaddle = player2
                cpuPaddle = player1
                menuState = 'confirm'
            end
        elseif menuState == 'confirm' then
            if love.keyboard.isDown('n') then
                menuState = 'modifyPaddleSpd'
            end
        end
    elseif gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            ball.dx = math.random(140, 200)
        else
            ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if ball:collides(player1) then
            ball.dx = -ball.dx * (1 + (BALL_ACCELERATION/100))
            ball.x = player1.x + 5

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end
        if ball:collides(player2) then
            ball.dx = -ball.dx * (1 + (BALL_ACCELERATION/100))
            ball.x = player2.x - 5

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- -4 to account for the ball's size
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            ball.y = VIRTUAL_HEIGHT - 4
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == VICTORY_SCORE then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end
    -- if we reach the right edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player1Score == VICTORY_SCORE then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end
    end

    if NUMBER_OF_PLAYERS == 2 then
        if love.keyboard.isDown('w') then
            player1.dy = -PADDLE_SPEED
        elseif love.keyboard.isDown('s') then
            player1.dy = PADDLE_SPEED
        else
            player1.dy = 0
        end

        if love.keyboard.isDown('up') then
            player2.dy = -PADDLE_SPEED
        elseif love.keyboard.isDown('down') then
            player2.dy = PADDLE_SPEED
        else
            player2.dy = 0
        end
    elseif NUMBER_OF_PLAYERS == 1 then
        if playerPaddle == player1 then
            if love.keyboard.isDown('w') then
                player1.dy = -PADDLE_SPEED
            elseif love.keyboard.isDown('s') then
                player1.dy = PADDLE_SPEED
            else
                player1.dy = 0
            end
    
            calcPaddleFinalYPosition(ball)
            cpuPaddleYDirection = calcCpuPaddleYDirection()
    
            player2.dy = PADDLE_SPEED * cpuPaddleYDirection 
        -- player 2
        elseif playerPaddle == player2 then
            if love.keyboard.isDown('up') then
                player2.dy = -PADDLE_SPEED
            elseif love.keyboard.isDown('down') then
                player2.dy = PADDLE_SPEED
            else
                player2.dy = 0
            end
    
            calcPaddleFinalYPosition(ball)
            cpuPaddleYDirection = calcCpuPaddleYDirection()
    
            player1.dy = PADDLE_SPEED * cpuPaddleYDirection
        end
    end
    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'startMenu' then
            if menuState == 'modifyPaddleSpd' then
                menuState = 'modifyBallAccel'
            elseif menuState == 'modifyBallAccel' then
                menuState = 'modifyVictoryScore'
            elseif menuState == 'modifyVictoryScore' then
                menuState = 'modifyNumOfPlayers'
            elseif menuState == 'modifyNumOfPlayers' then
                menuState = 'selectPlayer'
            elseif menuState == 'selectPlayer' then
                menuState = 'confirm'
            elseif menuState == 'confirm' then
                menuState = 'modifyPaddleSpd'
                gameState = 'start'
            end
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            gameState = 'startMenu'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    end
end

function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:apply('start')

    love.graphics.clear(40/255, 45/255, 52/255, 255/255)
    
    -- render different things depending on which part of the game we're in
    if gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'startMenu' then
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('', 0, 30, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' wins!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    if gameState ~= 'startMenu' then
        -- show the score before ball is rendered so it can move over the text
        displayScore()
    
        player1:render()
        player2:render()
        ball:render()

    -- display FPS for debugging; simply comment out to remove
        displayFPS()
    elseif gameState == 'startMenu' then
        
        displayPlayerSpeedSelection()
        displayBallAccelerationSelection()
        displayScoreForVictorySelection()
        displayNumberOfPlayersSelection()
        displayPlayerSelection()
        displayConfirmationButton()
        displaySelectionTriangle()
    end
    
    -- end our drawing to push
    push:apply('end')
end

function displayScore()
    -- score display
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50,
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end


function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end

function calcPaddleFinalYPosition(ball)
    if cpuPaddle ~= nil and next(cpuPaddle) ~= nil then
        cpuFinalYPosition = ball.y + (ball.height/2) - (cpuPaddle.height/2)
    
        if cpuFinalYPosition < 0 then
            return 0
        elseif cpuFinalYPosition + cpuPaddle.height > VIRTUAL_HEIGHT then
            return VIRTUAL_HEIGHT
        else
            return cpuFinalYPosition
        end
    end
end

function calcCpuPaddleYDirection()
    if cpuPaddle ~= nil and next(cpuPaddle) ~= nil then
        if cpuPaddle.y < cpuFinalYPosition then
            return 1
        elseif cpuPaddle.y > cpuFinalYPosition then
            return -1
        else
            return 0
        end
    end
end

function displayPlayerSpeedSelection()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('Players spd:'  .. PADDLE_SPEED, VIRTUAL_WIDTH/2, 25)
end

function displayBallAccelerationSelection()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('Ball Accel:'  .. BALL_ACCELERATION, VIRTUAL_WIDTH/2, 35)
end

function displayScoreForVictorySelection()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('Maximum Score:'  .. VICTORY_SCORE, VIRTUAL_WIDTH/2, 45)
end

function displayNumberOfPlayersSelection()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('Number of Players: 1      2' , VIRTUAL_WIDTH/2, 55)
end


function displayPlayerSelection()
    if NUMBER_OF_PLAYERS == 1 then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print('Select your player: 1      2', VIRTUAL_WIDTH/2, 65)
    end
end

function displayConfirmationButton()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('Confirm? Y     N', VIRTUAL_WIDTH/2, 75)
end


function displaySelectionTriangle(menuState)
    triangleX = VIRTUAL_WIDTH / 2 - 50
    triangleY = 0

    if menuState == 'modifyPaddleSpd' then
        triangleY = 25
    elseif menuState == 'modifyBallAccel' then
        triangleY = 35
    elseif menuState == 'modifyVictoryScore' then
        triangleY = 45
    elseif menuState == 'modifyNumOfPlayers' then
        triangleY = 55
    elseif menuState == 'selectPlayer' then
        triangleY = 65
    elseif menuState == 'confirm' then
        triangleY = 75
    end

    -- Draw the triangle
    love.graphics.setColor(1, 1, 1) -- Set color to white
    love.graphics.polygon('fill',
        triangleX, triangleY,                           -- Top vertex
        triangleX + 5, triangleY + 10,                  -- Bottom-left vertex
        triangleX + 10, triangleY)                      -- Bottom-right vertex
end
