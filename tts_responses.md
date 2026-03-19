# VoicePay TTS Responses & Triggers

This document lists all hardcoded Arabic responses used by the TTS (Text-to-Speech) model, categorized by their function.

## 1. Error & Validation Messages
| Trigger | Response (Arabic) |
| :--- | :--- |
| **Low Confidence/Unknown Intent** | عذراً، لم أفهم طلبك بشكل صحيح. هل يمكنك إعادة المحاولة؟ |
| **Multiple Entities Detected** | عذراً، لقد ذكرت أكثر من مستلم أو مبلغ واحد. يرجى ذكر تفاصيل عملية واحدة فقط. |
| **Missing Amount & Recipient** | عذراً، لم أفهم المبلغ والمستلم. هل يمكنك إعادة المحاولة وتحديدهما؟ |
| **Missing Recipient** | عذراً، لم أفهم لمن تريد التحويل. يرجى ذكر اسم المستلم. |
| **Missing Amount** | عذراً، لم أفهم المبلغ المطلوب. يرجى ذكر المبلغ بوضوح. |
| **Missing Bill Type** | عذراً، لم أفهم نوع الفاتورة التي تريد دفعها. |
| **Generic/Other Missing Details** | عذراً، لم أفهم بعض التفاصيل. هل يمكنك إعادة المحاولة؟ |

## 2. Account & Balance
| Trigger | Response (Arabic) |
| :--- | :--- |
| **Balance Inquiry Success** | أهلاً `{اسم_المستخدم}`، رصيدك الحالي هو `{المبلغ}` دينار أردني. |

## 3. Peer-to-Peer (P2P) Transfer
| Trigger | Response (Arabic) |
| :--- | :--- |
| **Insufficient Balance** | عذراً، رصيدك الحالي هو `{الرصيد}` دينار وهو غير كافٍ لإتمام هذه العملية بقيمة `{المبلغ}` دينار. |
| **Recipient Not Found** | عذراً، الاسم `{الاسم}` ليس ضمن قائمة الأسماء المحفوظة لديك. |
| **Inactive Recipient Account** | عذراً، لا يوجد حساب نشط للمستلم `{الاسم}`. |
| **Recipient Missing from DB** | عذراً، حساب المستلم غير موجود حالياً. |
| **Transfer to Self** | عذراً، لا يمكنك التحويل لنفسك. |
| **Confirmation Prompt** | هل تريد تأكيد تحويل مبلغ `{المبلغ}` دينار إلى `{المستلم}`؟ |
| **Transfer Success** | تم التحويل بنجاح. تم إرسال `{المبلغ}` دينار إلى `{المستلم}`. رصيدك الجديد هو `{الرصيد}` دينار. |

## 4. Bill Payment
| Trigger | Response (Arabic) |
| :--- | :--- |
| **Insufficient Balance** | عذراً، لا يمكنك دفع فاتورة `{الفاتورة}` لأن رصيدك `{الرصيد}` دينار أقل من قيمة الفاتورة `{القيمة}` دينار. |
| **Confirmation Prompt** | هل تريد تأكيد دفع فاتورة `{الفاتورة}` بقيمة `{القيمة}` دينار؟ |
| **Bill Already Paid** | لقد تم دفع فاتورة `{الفاتورة}` مسبقاً. |
| **Bill Type Not Found** | عذراً، لم أجد فاتورة باسم `{النوع}`. |
| **Payment Success** | تم دفع فاتورة `{الفاتورة}` بنجاح. رصيدك الجديد هو `{الرصيد}` دينار. |

## 5. Contact Management
| Trigger | Response (Arabic) |
| :--- | :--- |
| **User Reference Not Found** | عذراً، لا يوجد مستخدم مسجل بهذا الرقم المرجعي. يرجى التأكد من الرقم والمحاولة مرة أخرى. |
| **Duplicate Recipient** | هذا المستلم موجود بالفعل في قائمة جهات الاتصال الخاصة بك. |
| **Add Recipient Success** | تمت إضافة المستلم `{الاسم}` بنجاح! |
