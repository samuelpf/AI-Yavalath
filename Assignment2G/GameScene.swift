//
//  GameScene.swift
//  Assignment2G
//
//  Created by Oscar Samuel Pineda on 18/11/2016.
//  Student Number: 16200602
//

import SpriteKit
import GameplayKit


struct Position {
    var playerInTurn = 1
    var logicBoard = Array(repeating: 0, count: 121)
    var movesPlayed = 0
    var move = -1
    var sortingPriority = 0
}


enum Heuristic {
    case none
    case killerMove
    case historyMove
}


class GameScene: SKScene {
    
    // GUI variables
    var gameBoard: [SKSpriteNode] = []
    var turnLabel: SKLabelNode!
    var playAgainBtn: SKLabelNode!
    
    
    // Constants
    let infinity = Int.max
    let boardSize = 61
    var playableCells = [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0,
        0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0,
        0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]
    let patterns = [
        [1, 1, 0],
        [0, 1, 1],
        [1, 0, 1],
        [1, 0, 0, 1],
        [1, 1, 0, 1],
        [1, 0, 1, 1],
        [1, 1, 1],
        [1, 1, 1, 1]
    ]
    let patternValues = [-1, -1, -1, 2, 10, 10, -50, 200]
    let totalPatterns = 8
    let maxPatternLength = 4
    
    
    // Global variables
    var currentPosition = Position()
    var killerMoves = Array<Array<Int>>()
    var historyMoves = Array<Dictionary<Int,Int>>()
    var gameInProgress = false
    
    
    // Variables for statistics
    var SECounter = 0
    
    
    // Customisable parameters
    let searchDepth = 2
    let useHeuristic = Heuristic.killerMove
    
    
    func evaluationFunction(position: Position) -> Int {
        var score = 0
        let directions = [1, 10, 11]
        var patternCount = Array(repeating: 0, count: totalPatterns)
        
        for cell in 0..<position.logicBoard.count {
            if playableCells[cell] == 0 { continue }
            
            for delta in directions {
                var cellIndex = cell
                var cellPlayer = position.logicBoard[cellIndex]
                if cellPlayer == 0 { cellPlayer = position.logicBoard[cellIndex + delta] }
                var patternMatch = Array(repeating: cellPlayer, count: totalPatterns)
                
                for innerIndex in 0 ..< maxPatternLength {
                    if cellIndex >= position.logicBoard.count { break }
                    for (outerIndex, pattern) in patterns.enumerated() {
                        if innerIndex < pattern.count {
                            if playableCells[cellIndex] == 0 ||
                               (pattern[innerIndex] == 0 && position.logicBoard[cellIndex] != 0) ||
                               (pattern[innerIndex] == 1 && position.logicBoard[cellIndex] != cellPlayer) {
                                patternMatch[outerIndex] = 0
                            }
                        }
                    }
                    cellIndex = cellIndex + delta
                }
                
                for (pIndex, pattern) in patternMatch.enumerated() {
                    if pattern > 0 {
                        let countRes = pattern == position.playerInTurn ? 1 : -1
                        patternCount[pIndex] = patternCount[pIndex] + countRes
                    }
                }
            }
        }
        
        for (pIndex, pattern) in patternCount.enumerated() {
            score = score + patternValues[pIndex] * pattern
        }
        
        return score
    }
    
    
    // Implementation of negamax variant of alpha-beta
    func abNegamax(position: Position, height: Int, alpha: Int, beta: Int) -> (value: Int, bestMove: Int) {
        var alpha = alpha
        
        if height == 0 || position.movesPlayed == boardSize || position.movesPlayed == boardSize {
            let tuple = (value: evaluationFunction(position: position), bestMove: -1)
            SECounter = SECounter + 1
            return tuple
            
        } else {
            // Ply is the distance to the root node...
            let ply = searchDepth - height - 1
            var temp = 0, bestMove = 0
            
            // Create all possible moves from this position and store them in a list
            var possibleMoves = [Position]()
            
            for cell in 0 ..< position.logicBoard.count {
                if playableCells[cell] == 0 || position.logicBoard[cell] != 0 { continue }
                
                var newPosition = position
                newPosition.playerInTurn = newPosition.playerInTurn == 1 ? 2 : 1
                newPosition.logicBoard[cell] = position.playerInTurn
                newPosition.movesPlayed = newPosition.movesPlayed + 1
                newPosition.move = cell
                
                if useHeuristic == .killerMove {
                    if ply >= 0 {
                        for (kmIndex, killerMove) in killerMoves[ply].enumerated() {
                            if killerMove == newPosition.move {
                                newPosition.sortingPriority = abs(kmIndex - 1) + 1
                            }
                        }
                    }
                } else if useHeuristic == .historyMove {
                    let pIndex = position.playerInTurn == 1 ? 0 : 1
                    for (move, priority) in historyMoves[pIndex] {
                        if move == newPosition.move {
                            newPosition.sortingPriority = priority
                        }
                    }
                }
                
                possibleMoves.append(newPosition)
            }
            
            // Sort array of possible moves
            if useHeuristic != .none {
                possibleMoves.sort(by: { $0.sortingPriority > $1.sortingPriority })
            }
            
            // Iterate over all the moves in the list
            for position in possibleMoves {
                let abTuple = abNegamax(position: position, height: height-1, alpha: -beta, beta: -alpha)
                temp = -abTuple.value
                
                if temp >= beta {
                    if useHeuristic == .killerMove {
                        if ply >= 0 {
                            killerMoves[ply][1] = killerMoves[ply][0]
                            killerMoves[ply][0] = position.move
                        }
                    } else if useHeuristic == .historyMove {
                        let pIndex = position.playerInTurn == 1 ? 0 : 1
                        if historyMoves[pIndex][position.move] != nil {
                            historyMoves[pIndex][position.move] = historyMoves[pIndex][position.move]! + 1
                        } else {
                            historyMoves[pIndex][position.move] = 1
                        }
                    }
                    
                    return (value: temp, bestMove: -1)
                }
                
                if temp > alpha {
                    alpha = temp
                    bestMove = position.move
                }
            }
            
            return (value: alpha, bestMove: bestMove)
        }
    }
    
    
    func startNewGame() {
        gameInProgress = true
        currentPosition = Position()
        
        for node in gameBoard {
            node.texture = nil
        }
        
        playAgainBtn.text = "Play again"
        playAgainBtn.isHidden = true
        turnLabel.text = currentPosition.playerInTurn == 1 ? "Your move" : "A.I. is thinking..."
    }
    
    
    func checkIfThereIsAWinner() {
        let firstValidCell = 16
        let lastValidCell = 104
        
        var winner = 0
        for cell in firstValidCell...lastValidCell {
            winner = lookForSequence(cell)
            if winner > 0 { break }
        }
        
        if winner > 0 || currentPosition.movesPlayed == boardSize {
            gameInProgress = false
            playAgainBtn.isHidden = false
            if winner > 0 {
                turnLabel.text = winner == 1 ? "You win!" : "You lose..."
            } else {
                turnLabel.text = "It was a draw..."
            }
        } else {
            currentPosition.playerInTurn = currentPosition.playerInTurn == 1 ? 2 : 1
            currentPosition.movesPlayed = currentPosition.movesPlayed + 1
            turnLabel.text = currentPosition.playerInTurn == 1 ? "Your move" : "A.I. is thinking..."
        }
    }
    
    
    func lookForSequence(_ cell: Int) -> Int {
        let player = currentPosition.logicBoard[cell]
        if player == 0 { return 0 }
        
        var largestSequence = 1
        let directions = [1, 10, 11]
        
        for delta in directions {
            var index = cell
            var keepLooking = true
            largestSequence = 1
            
            while keepLooking {
                index = index + delta
                if index < currentPosition.logicBoard.count && playableCells[index] == 1 {
                    if currentPosition.logicBoard[index] == player {
                        largestSequence = largestSequence + 1
                    } else {
                        keepLooking = false
                    }
                } else {
                    keepLooking = false
                }
            }
            
            if largestSequence == 3 { return player == 1 ? 2 : 1 }
            if largestSequence == 4 { return player }
        }
        
        if currentPosition.movesPlayed == boardSize { return 3 }
        return 0
    }
    
    
    func tryMoveFromHumanPlayer(_ cellName: String) -> Bool {
        if !gameInProgress { return false }
        let cellName = "//" + cellName
        var cell = 0
        
        if cellName.contains("C-") {
            cell = Int(cellName.substring(from: cellName.index(cellName.startIndex, offsetBy: 4)))!
        } else {
            return false
        }
        
        cell = translateCellFromGUIToLogicBoard(cell)
        
        if currentPosition.logicBoard[cell] == 0 {
            currentPosition.logicBoard[cell] = 1
            
            if let node = self.childNode(withName: cellName) as? SKSpriteNode {
                node.texture = SKTexture(imageNamed: "oval-blue")
            }
            
            checkIfThereIsAWinner()
            return true
        }
        
        return false
    }
    
    
    func AIMove() {
        if !gameInProgress { return }
        
        // Restart counters and heuristics data
        SECounter = 0
        for _ in 0 ..< searchDepth { killerMoves.append(Array(repeating: -1, count: 2)) }
        for _ in 0 ..< 2 { historyMoves.append(Dictionary()) }
        
        let abTuple = abNegamax(position: currentPosition, height: searchDepth, alpha: -infinity, beta: infinity)
        let bestMove = translateCellFromLogicBoardToGUI(abTuple.bestMove)
        currentPosition.logicBoard[abTuple.bestMove] = 2
        print("SE performed: \(SECounter)")
        
        let cellName = bestMove/10 < 1 ?  "//C-0\(bestMove)" : "//C-\(bestMove)"
        if let node = self.childNode(withName: cellName) as? SKSpriteNode {
            node.texture = SKTexture(imageNamed: "oval-red")
        }
        
        checkIfThereIsAWinner()
    }
    
    
    func translateCellFromGUIToLogicBoard(_ cell: Int) -> Int {
        var column = 0, row = 0
        
        let cellsInColumn = [5,6,7,8,9,8,7,6,5]
        var lowerBound = 61
        for (index, element) in cellsInColumn.enumerated() {
            lowerBound = lowerBound - element
            
            if cell >= lowerBound {
                row = cellsInColumn.count - index
                column = cell - lowerBound
                break
            }
        }
        
        let offsetInLogicBoardRows = [0,5,4,3,2,1,1,1,1,1,0]
        column = column + offsetInLogicBoardRows[row]
        return 11*row + column
    }
    
    
    func translateCellFromLogicBoardToGUI(_ cell: Int) -> Int {
        let cellsInColumn = [5,6,7,8,9,8,7,6,5]
        let offsetInLogicBoardRows = [0,5,4,3,2,1,1,1,1,1,0]
        
        let column = (cell / 11) - 1
        let row = (cell % 11) - offsetInLogicBoardRows[column + 1]
        
        var partialSum = 0
        for index in 0 ..< column {
            partialSum = partialSum + cellsInColumn[index]
        }
        return partialSum + row
    }
    
    
    override func didMove(to view: SKView) {
        turnLabel = self.childNode(withName: "//turnLabel") as! SKLabelNode
        playAgainBtn = self.childNode(withName: "//playAgainBtn") as! SKLabelNode
        
        self.enumerateChildNodes(withName: "//C-*") { (node, stop) in
            if let node = node as? SKSpriteNode {
                node.color = UIColor.clear
                self.gameBoard.append(node)
            }
        }
        
        startNewGame()
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let selectedNode = self.atPoint(location)
            
            if let cellName = selectedNode.name {
                if cellName.contains("playAgainBtn") {
                    startNewGame()
                    return
                }
                
                if currentPosition.playerInTurn != 1 { return }
                let validMove = tryMoveFromHumanPlayer(cellName)
                if validMove {
                    DispatchQueue.global(qos: .background).async {
                        self.AIMove()
                    }
                }
            }
        }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
