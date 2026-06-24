package com.bankapp.repository;

import com.bankapp.model.UPITransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface UPITransactionRepository extends JpaRepository<UPITransaction, String> {
    List<UPITransaction> findTop3ByAccountIdOrderByTransactionDateDesc(String accountId);
}