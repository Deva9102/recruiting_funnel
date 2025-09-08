# Recruiting Funnel Analytics Project

This project analyzes a recruitment pipeline using **SQLite + SQL**.  
It uses a **star schema** design with fact/dimension tables and builds **analytics views** for conversion rates, stage durations, and funnel drop-offs.  
Data exports can be visualized in Tableau for dashboards.

## 📂 Project Structure
- `data/` → SQLite DB, raw data
- `sql/` → schema.sql, transform.sql, analytics.sql
- `exports/` → CSV exports of views for Tableau
- `docs/` → ER diagram & star schema
- `README.md` → project overview
- `.gitignore` → ignored files (db, system files, etc.)

## ⚙️ Steps to Run
1. Run `sql/schema.sql` → creates tables.  
2. Run `sql/transform.sql` → populates star schema.  
3. Run `sql/analytics.sql` → creates analytical views.  
4. Export results from views or connect directly to Tableau.  

## 📊 Key Insights
- Most drop-offs occur **before interviews**.  
- **Graduates** have higher hire rates (~71%) than non-graduates (~61%).  
- **Semiurban candidates** convert better (~77%) than urban (~66%) or rural (~61%).  
- **Screening stage** is the bottleneck (~8 days average).  

## 🛠️ Tech Stack
- SQLite 3.45  
- SQL (DDL, DML, Views)  
- Tableau (for visualization)

---

