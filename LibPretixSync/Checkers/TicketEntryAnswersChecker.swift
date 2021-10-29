//
//  TicketAnswersValidator.swift
//  pretixSCAN
//
//  Created by Konstantin Kostov on 28/10/2021.
//  Copyright © 2021 rami.io. All rights reserved.
//

import Foundation

/// Performs dataless check if the provided answers allow entry
final class TicketEntryAnswersChecker {
    private var item: Item
    weak var dataStore: SignedDataStore?
    
    init(item: Item, dataStore: SignedDataStore) {
        self.item = item
        self.dataStore = dataStore
    }
    
    func redeem(ticket: SignedTicketData, event: Event, answers: [Answer]?) -> Result<Void, CheckStatus> {
        guard let result = dataStore?.getQuestions(for: self.item, in: event) else {
            fatalError("dataStore instance has been disposed")
        }
        
        switch result {
        case .success(let questions):
            let incompleteQuestions = questions
                .filter({$0.askDuringCheckIn && $0.isRequired})
                .filter({!questionIsAnswered($0, answers)})
            
            return incompleteQuestions.isEmpty ? .success(()) : .failure(.incomplete(questions: incompleteQuestions))
        case .failure(let err):
            EventLogger.log(event: "Failed to get questions during ticket validation: \(err.localizedDescription)", category: .database, level: .error, type: .error)
            return .failure(.unknownError)
        }
    }
    
    /// Checks if the `Question` has a meaningful `Answer`.
    func questionIsAnswered(_ q: Question, _ answers: [Answer]?) -> Bool {
        guard let answers = answers else {
            return false
        }
        
        if let answer = answers.first(where: {$0.question == q.identifier}) {
            switch q.type {
            case .boolean:
                // required boolean questions must answer "true"
                return answer.answer.lowercased() == "true"
            default:
                return !answer.answer.isEmpty
            }
        }
        
        return false
    }
    
    enum CheckStatus: Error, Hashable, Equatable {
        /// Some qiestions do not have a valid answer
        case incomplete(questions: [Question])
        case unknownError
    }
}
