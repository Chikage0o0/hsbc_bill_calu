//! This `hub` crate is the
//! entry point of the Rust logic.

mod common;
mod messages;

use std::sync::{Arc, LazyLock};

use crate::common::*;
use arc_swap::ArcSwap;

#[cfg(not(target_arch = "wasm32"))]
use tokio; // Comment this line to target the web.
           // use tokio_with_wasm::alias as tokio; // Uncomment this line to target the web.

#[cfg(target_arch = "wasm32")]
use tokio_with_wasm::alias as tokio; // Comment this line to target the web.
                                     // use tokio_with_wasm::alias as tokio; // Uncomment this line to target the web.

rinf::write_interface!();

#[derive(Debug, Clone, Default)]
struct State {
    start_date: Option<chrono::NaiveDate>,
    end_date: Option<chrono::NaiveDate>,
}

static STATE: LazyLock<ArcSwap<State>> = LazyLock::new(|| ArcSwap::from_pointee(State::default()));

async fn main() {
    tokio::spawn(calu());
    tokio::spawn(set_date());
}

async fn set_date() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    use messages::basic::*;

    let mut receiver = DateRequest::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        if let Some(date) = signal.message.date {
            let date_type = DateType::try_from(signal.message.date_type)?;
            match date_type {
                DateType::Start => {
                    let start_date =
                        chrono::NaiveDate::from_ymd_opt(date.year, date.month, date.day).unwrap();
                    let mut state = STATE.load_full().as_ref().clone();
                    state.start_date = Some(start_date);
                    STATE.store(Arc::new(state));
                }
                DateType::End => {
                    let end_date =
                        chrono::NaiveDate::from_ymd_opt(date.year, date.month, date.day).unwrap();
                    let mut state = STATE.load_full().as_ref().clone();
                    state.end_date = Some(end_date);
                    STATE.store(Arc::new(state));
                }
            }
        }
    }

    Ok(())
}

async fn calu() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    use messages::basic::*;
    // Send signals to Dart like below.

    let mut receiver = CsvData::get_dart_signal_receiver()?;
    while let Some(signal) = receiver.recv().await {
        let csv_bytes = signal.binary;
        let date = STATE.load_full();
        let start_date = date.start_date;
        let end_date = date.end_date;
        match (start_date, end_date) {
            (Some(start_date), Some(end_date)) => {
                if start_date >= end_date {
                    CalulateResponse {
                        status: Status::Error as i32,
                        result: "开始日期不能大于等于结束日期".to_string(),
                    }
                    .send_signal_to_dart();
                } else {
                    let total = calu_total_bills(csv_bytes, start_date, end_date);
                    if total == 0.0 {
                        CalulateResponse {
                            status: Status::Error as i32,
                            result: "没有数据".to_string(),
                        }
                        .send_signal_to_dart();
                        continue;
                    } else {
                        CalulateResponse {
                            status: Status::Ok as i32,
                            result: format!("您的支出为：{:.2}", total),
                        }
                        .send_signal_to_dart();
                    }
                }
            }
            (Some(_), None) => {
                CalulateResponse {
                    status: Status::Error as i32,
                    result: "请先设置结束日期".to_string(),
                }
                .send_signal_to_dart();
            }
            (None, Some(_)) => {
                CalulateResponse {
                    status: Status::Error as i32,
                    result: "请先设置开始日期".to_string(),
                }
                .send_signal_to_dart();
            }
            (None, None) => {
                CalulateResponse {
                    status: Status::Error as i32,
                    result: "请先设置开始日期和结束日期".to_string(),
                }
                .send_signal_to_dart();
            }
        }
    }

    Ok(())
}
