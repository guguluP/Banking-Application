package com.bankapp.repository;

import com.bankapp.model.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, String> {
    List<Transaction> findByAccountIdOrderByTransactionDateDesc(String accountId);
    List<Transaction> findTop5ByAccountIdOrderByTransactionDateDesc(String accountId);
}