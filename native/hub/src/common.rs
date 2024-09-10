use chrono::NaiveDate;
use serde::Deserialize;

#[derive(Debug, serde::Deserialize)]
struct Bill {
    #[serde(rename = "Transaction date")]
    #[serde(deserialize_with = "string_to_date")]
    transaction_date: NaiveDate,
    #[serde(rename = "Merchant name")]
    merchant_name: String,
    #[serde(rename = "Billing amount")]
    #[serde(deserialize_with = "string_to_float64")]
    billing_amount: f64,
}

pub fn calu_total_bills(csv_bytes: Vec<u8>, start: NaiveDate, end: NaiveDate) -> f64 {
    let mut rdr = csv::Reader::from_reader(csv_bytes.as_slice());
    let bills: Vec<Bill> = rdr
        .deserialize()
        .into_iter()
        .filter_map(Result::ok)
        .collect();

    let mut total = 0.0;
    for bill in bills {
        if bill.merchant_name.is_empty() {
            continue;
        }

        if bill.transaction_date < start {
            continue;
        }

        if bill.transaction_date > end {
            continue;
        }

        total += bill.billing_amount;
    }
    -total
}

fn string_to_float64<'de, D>(deserializer: D) -> Result<f64, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    let s = s.replace(",", "").replace("\t", "");
    Ok(s.parse().unwrap())
}

fn string_to_date<'de, D>(deserializer: D) -> Result<NaiveDate, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    Ok(NaiveDate::parse_from_str(&s, "%d/%m/%Y").unwrap())
}
