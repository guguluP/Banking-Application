package com.bankapp.model;

import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "upi_transactions")
public class UPITransaction {
    @Id
    private String id;
    private String accountId;
    private String upiId;
    private BigDecimal amount = BigDecimal.ZERO;
    private String remarks;
    private String transactionDate;

    public UPITransaction() {}

    public UPITransaction(String id, String accountId, String upiId, BigDecimal amount, String remarks, String transactionDate) {
        this.id = id;
        this.accountId = accountId;
        this.upiId = upiId;
        this.amount = amount;
        this.remarks = remarks;
        this.transactionDate = transactionDate;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getAccountId() { return accountId; }
    public void setAccountId(String accountId) { this.accountId = accountId; }
    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public String getRemarks() { return remarks; }
    public void setRemarks(String remarks) { this.remarks = remarks; }
    public String getTransactionDate() { return transactionDate; }
    public void setTransactionDate(String transactionDate) { this.transactionDate = transactionDate; }
}
