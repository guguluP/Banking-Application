package com.bankapp.service;

import com.bankapp.model.Account;
import com.bankapp.model.Transaction;
import com.bankapp.model.TransactionType;
import com.bankapp.repository.AccountRepository;
import com.bankapp.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service
public class AccountService {
    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private TransactionRepository transactionRepository;
    
    public List<Account> getUserAccounts(String userId) {
        return accountRepository.findByUserId(userId);
    }
    
    public List<Account> getAllAccounts() {
        return accountRepository.findAll();
    }
    
    @Transactional
    public boolean transfer(String fromAccountId, String toAccountId, BigDecimal amount) {
        Account fromAccount = accountRepository.findById(fromAccountId).orElse(null);
        Account toAccount = accountRepository.findById(toAccountId).orElse(null);
        
        if (fromAccount == null || toAccount == null) {
            return false;
        }
        
        BigDecimal fromAvailable = fromAccount.getAvailableBalance();
        BigDecimal toAvailable = toAccount.getAvailableBalance();
        BigDecimal fromBalance = fromAccount.getBalance();
        BigDecimal toBalance = toAccount.getBalance();
        
        if (fromAvailable.compareTo(amount) < 0) {
            return false;
        }
        
        fromAccount.setBalance(fromBalance.subtract(amount).setScale(2, RoundingMode.HALF_UP));
        fromAccount.setAvailableBalance(fromAvailable.subtract(amount).setScale(2, RoundingMode.HALF_UP));
        
        toAccount.setBalance(toBalance.add(amount).setScale(2, RoundingMode.HALF_UP));
        toAccount.setAvailableBalance(toAvailable.add(amount).setScale(2, RoundingMode.HALF_UP));
        
        accountRepository.save(fromAccount);
        accountRepository.save(toAccount);
        
        String transferId = "txn_" + UUID.randomUUID().toString().substring(0, 8);
        
        Transaction debitTxn = new Transaction();
        debitTxn.setId(transferId + "_debit");
        debitTxn.setAccountId(fromAccountId);
        debitTxn.setTransactionType(TransactionType.transfer);
        debitTxn.setAmount(amount.setScale(2, RoundingMode.HALF_UP));
        debitTxn.setDescription("Transfer to account " + toAccountId);
        debitTxn.setCounterparty(toAccountId);
        debitTxn.setTransactionDate(java.time.LocalDateTime.now().toString());
        debitTxn.setCredit(false);
        transactionRepository.save(debitTxn);
        
        Transaction creditTxn = new Transaction();
        creditTxn.setId(transferId + "_credit");
        creditTxn.setAccountId(toAccountId);
        creditTxn.setTransactionType(TransactionType.transfer);
        creditTxn.setAmount(amount.setScale(2, RoundingMode.HALF_UP));
        creditTxn.setDescription("Transfer from account " + fromAccountId);
        creditTxn.setCounterparty(fromAccountId);
        creditTxn.setTransactionDate(java.time.LocalDateTime.now().toString());
        creditTxn.setCredit(true);
        transactionRepository.save(creditTxn);
        
        return true;
    }
}