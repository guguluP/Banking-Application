package com.bankapp.service;

import com.bankapp.model.Transaction;
import com.bankapp.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class TransactionService {
    @Autowired
    private TransactionRepository transactionRepository;
    
    public List<Transaction> getRecentTransactions(String accountId) {
        return transactionRepository.findTop5ByAccountIdOrderByTransactionDateDesc(accountId);
    }
}
