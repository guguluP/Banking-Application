package com.bankapp.model;

import com.fasterxml.jackson.annotation.JsonValue;
import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "transactions")
public class Transaction {
    @Id
    private String id;
    private String accountId;

    @Enumerated(EnumType.STRING)
    private TransactionType transactionType;

    private BigDecimal amount = BigDecimal.ZERO;
    private String description;
    private String counterparty;
    private String transactionDate;
    private boolean isCredit = true;

    public Transaction() {}

    public Transaction(String id, String accountId, TransactionType transactionType, BigDecimal amount, String description, String counterparty, String transactionDate, boolean isCredit) {
        this.id = id;
        this.accountId = accountId;
        this.transactionType = transactionType;
        this.amount = amount;
        this.description = description;
        this.counterparty = counterparty;
        this.transactionDate = transactionDate;
        this.isCredit = isCredit;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getAccountId() { return accountId; }
    public void setAccountId(String accountId) { this.accountId = accountId; }
    public TransactionType getTransactionType() { return transactionType; }
    public void setTransactionType(TransactionType transactionType) { this.transactionType = transactionType; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getCounterparty() { return counterparty; }
    public void setCounterparty(String counterparty) { this.counterparty = counterparty; }
    public String getTransactionDate() { return transactionDate; }
    public void setTransactionDate(String transactionDate) { this.transactionDate = transactionDate; }
    public boolean isCredit() { return isCredit; }
    public void setCredit(boolean credit) { isCredit = credit; }

    public enum TransactionType {
        deposit, withdrawal, transfer, payment, fee, interest;
        
        @JsonValue
        public String toJson() {
            return switch (this) {
                case deposit -> "Deposit";
                case withdrawal -> "Withdrawal";
                case transfer -> "Transfer";
                case payment -> "Payment";
                case fee -> "Fee";
                case interest -> "Interest";
            };
        }
    }
}
