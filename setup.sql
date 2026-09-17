create database ecommerce_analytics;


create table website_sessions (
    website_session_id int primary key,
    created_at timestamp,
    user_id int,
    is_repeat_session int,
    utm_source text,
    utm_campaign text,
    utm_content text,
    device_type text,
    http_referer text
);



select table_name from information_schema.tables 
where table_schema='public';


select column_name from information_schema.columns 
where table_name='website_sessions';


copy website_sessions
from 'F:\Ecommerce CSV\website_sessions.csv'
with(
    format CSV,
    Header TRUE
);


create table orders (
    order_id int primary key,
    created_at timestamp,
    website_session_id int,
    user_id int,
    primary_product_id int,
    items_purchased int,
    price_usd numeric(10,2),
    cogs_usd Numeric(10,2)
);


Copy orders
from 'F:\Ecommerce CSV\orders.csv'
with(
    FORMAT csv,
    header true
);


select count(*) from orders;


select * from orders limit 10;


select order_id, created_at, user_id, price_usd
from orders
limit 10;


select order_id, price_usd,cogs_usd
from orders
limit 10;


select order_id, created_at,price_usd,cogs_usd
from orders
where price_usd > 50
limit 10;


select order_id,user_id, items_purchased
from orders
where items_purchased>1
limit 10;


select order_id,user_id,price_usd
from orders
order by order_id DESC
limit 10;


### Monthly Business Performance Analysis

with monthly_session as (
    select
        date_trunc('month', created_at):: date as month,
        count(*) as sessions 
    from website_sessions
    group by 1
),
monthly_orders as(
    SELECT
        date_trunc('month', created_at):: date as month,
        COUNT(*) as orders,
    sum(price_usd) as revenue
    from orders
    group by 1
)
SELECT
    s.month,
    s.sessions,
    coalesce(o.orders,0) as orders,
    coalesce(o.revenue,0) as revenue,

    round(
        100.0* coalesce(o.orders, 0)/nullif(s.sessions,0),
        2
    ) as conversion_rate_pct,

    round(
        coalesce(o.revenue, 0)/nullif(o.orders,0),
        2
    ) as revenue_per_order,
    
    round(
        coalesce(o.revenue, 0)/nullif(s.sessions,0),
        2
    ) as revenue_per_session

    from monthly_session s 
    left join monthly_orders o 
        on s.month=o.month 
    order by s.month;




update website_sessions
set utm_source= NULL
where utm_source='NULL';




update website_sessions
set http_referer=NULL
where http_referer='NULL'





### Marketing channel performance Analysis

with session_channels as (
    SELECT
     website_session_id,

        CASE
            when utm_source='gsearch'
                then 'Paid Search - GSearch'
            when utm_source = 'bsearch'
                then 'Paid Search - BSearch'
            when utm_source = 'socialbook'
                then 'Paid Social'
            when utm_source is NULL
                and http_referer is not NULL
                then 'Organic Search'
            when utm_source is NULL
                and http_referer is NULL
                then 'Direct'
            else 'other'
        end as marketing_channel
    from website_sessions
)
SELECT
    sc.marketing_channel,
    count(distinct sc.website_session_id) as sessions,
    count(distinct o.order_id) as orders,
    coalesce(sum(o.price_usd),0) as revenue,
    Round(
        100.0* count(distinct o.order_id)
        /nullif(count(distinct sc.website_session_id),0),
        2
    ) as conversion_rate_pct,
    
    round(
        coalesce(sum(o.price_usd),0)
        /nullif(count(distinct sc.website_session_id),0),
        2
    ) as revenue_per_session

    from session_channels sc 
    
    left join orders o 
        on sc.website_session_id = o.website_session_id
    group by sc.marketing_channel
    order by revenue desc;




    SELECT
        count(*) as total_null_source,

        count(*) filter (
            where http_referer is NULL
        ) as direct_sessions,

        count(*) filter (
            where http_referer is not NULL
        ) as organic_sessions

    from website_sessions
    where utm_source is NULL;    



    SELECT
        count(*) filter (where utm_source= '') as blank_utm_source,
        count(*) filter (where http_referer= '') as blank_utm_referer
    from website_sessions;



    SELECT
        utm_source,
        count(*) as ROWS
    from website_sessions
    group by utm_source
    order by rows desc;


    SELECT count(*)
    from website_sessions
    where utm_source is NULL;




#### creating order_items table


create table order_items(
    order_items_id int primary key,
    created_at TIMESTAMP,
    order_id int,
    product_id int,
    is_primary_item int,
    price_usd numeric(10,2),
    cogs_usd numeric(10,2)
);



#### Importing order_items table 


copy order_items
from 'F:\Ecommerce CSV\order_items.csv'
with (
    format CSV,
    header TRUE
);


####checking order_items file imported or NOT


select count(*) from order_items;




#### creating products TABLE

create table products(
    product_id int primary key,
    created_at timestamp,
    product_name TEXT
);



#### importing products TABLE

copy products
from 'F:\Ecommerce CSV\products.csv'
with(
    format csv,
    header TRUE
);


#### checking file improted or NOT

select count(*) from products;



#### creating order_items_refunds TABLE

create table order_item_refunds(
    order_item_refunds_id int primary key,
    created_at timestamp,
    order_item_id int,
    order_id int,
    refund_amount_usd NUMERIC(10,2)
);


#### importing order_item_refunds file 

copy order_item_refunds
from 'F:\Ecommerce CSV\order_item_refunds.csv'
with (
    format CSV,
    header TRUE
);


#### checking file imported or NOT

select count(*) from order_item_refunds;






#### checking column NAME

select column_name
from information_schema.columns
where table_name='order_items';



#### renaming COLUMN

Alter table order_items
rename column order_items_id to order_item_id;









#### product performance Analysis

with product_sales as (
    select 
    p.product_id,
    p.product_name,
    count(distinct oi.order_id) as product_orders,
    count(oi.order_item_id) as items_sold,
    sum(oi.price_usd) as revenue,
    sum(oi.cogs_usd) as cogs,
    sum(oi.price_usd- oi.cogs_usd) as profit
    from order_items oi 
    join products p 
        on oi.product_id=p.product_id
        group by p.product_id, p.product_name
),

product_refunds as (
    SELECT
        oi.product_id,
        count(distinct r.order_item_id) as refunded_items,
        coalesce(sum(r.refund_amount_usd),0) as refund_amount 
    from order_items oi 
    left join order_item_refunds r 
        on oi.order_item_id=r.order_item_id
        group by oi.product_id
)

SELECT
    ps.product_name,
    ps.product_orders,
    ps.items_sold,
    ps.revenue,
    ps.profit,

    round(
        100.0* ps.profit/NULLIF(ps.revenue,0),
        2
    ) as profit_margin_pct,

    pr.refunded_items,
    pr.refund_amount,

    round(
        100.0* pr.refunded_items/NULLIF(ps.items_sold,0),
        2
    ) as refund_rate_pct

    from product_sales ps 
    
    left join product_refunds pr 
        on ps.product_id=pr.product_id
    order by ps.revenue desc;




    #### Monthly product performance trend

    SELECT 
        date_trunc('month',oi.created_at):: date as month,
        p.product_name,
        count(Distinct oi.order_id) as product_orders,
        
        sum(oi.price_usd) as revenue,
        
        sum(oi.price_usd-oi.cogs_usd) as profit,

        round(
            100.0*sum(oi.price_usd-oi.cogs_usd)
            /NullIF(sum(oi.price_usd),0),
            2
        ) as profit_margin_pct
    
    from order_items oi 
    
    join products p 
        on oi.product_id=p.product_id

    group by
        date_trunc('month',oi.created_at)::date,
        p.product_name

    order BY
        month,
        revenue desc;



#### New vs repeat customer performance 

with customer_type as (
    SELECT
        website_session_id,
        CASE
            when is_repeat_session= 1 THEN 'Repeat'
            else 'New'
        end as session_type
    from website_sessions
)

SELECT
    ct.session_type,

    count( distinct ct.website_session_id) as sessions,
    count( distinct o.order_id) as orders,
    coalesce(sum(o.price_usd),0) as revenue,
    round(
        100.0* count(distinct o.order_id)
        / NULLIF(count(distinct ct.website_session_id),0),
        2
    ) as conversion_rate_pct,
    round (
        COALESCE(sum(o.price_usd),0)
        /NULLIF(count(distinct ct.website_session_id),0),
        2
    ) as revenue_per_session

    from customer_type ct 
    left join orders o 
        on ct.website_session_id=o.website_session_id
    group by ct.session_type
    order by conversion_rate_pct desc;



#### creating table to import website_pageviews

    create table website_pageviews(
        website_pageviews_id int primary KEY,
        created_at timestamp,
        website_session_id int,
        pageview_url TEXT
    );


#### importing website_pageviews TABLE

    COPY website_pageviews
    from 'F:\Ecommerce CSV\website_pageviews.csv'
    with(
        format csv,
        header TRUE
    );


#### checking table imported correctly or NOT

    Select count(*) from website_pageviews
    where pageview_url='/products';






SELECT
    pageview_url,
    count(*) as ROWS
from website_pageviews
group by pageview_url
order by rows desc;




#### correcting table name of website_pageviews

alter table website_pageviews
rename column website_pageviews_id to website_pageview_id;






#### Funnel analysis of customer stage 

   WITH products_stage AS (
    SELECT
        website_session_id,
        MIN(created_at) AS products_at
    FROM website_pageviews
    WHERE pageview_url = '/products'
    GROUP BY website_session_id
),

cart_stage AS (
    SELECT
        p.website_session_id,
        p.products_at,
        MIN(w.created_at) AS cart_at
    FROM products_stage p
    LEFT JOIN website_pageviews w
        ON p.website_session_id = w.website_session_id
        AND w.pageview_url = '/cart'
        AND w.created_at > p.products_at
    GROUP BY p.website_session_id, p.products_at
),

shipping_stage AS (
    SELECT
        c.website_session_id,
        c.products_at,
        c.cart_at,
        MIN(w.created_at) AS shipping_at
    FROM cart_stage c
    LEFT JOIN website_pageviews w
        ON c.website_session_id = w.website_session_id
        AND w.pageview_url = '/shipping'
        AND w.created_at > c.cart_at
    GROUP BY c.website_session_id, c.products_at, c.cart_at
),

billing_stage AS (
    SELECT
        s.website_session_id,
        s.products_at,
        s.cart_at,
        s.shipping_at,
        MIN(w.created_at) AS billing_at
    FROM shipping_stage s
    LEFT JOIN website_pageviews w
        ON s.website_session_id = w.website_session_id
        AND w.pageview_url IN ('/billing', '/billing-2')
        AND w.created_at > s.shipping_at
    GROUP BY
        s.website_session_id,
        s.products_at,
        s.cart_at,
        s.shipping_at
),

purchase_stage AS (
    SELECT
        b.website_session_id,
        b.products_at,
        b.cart_at,
        b.shipping_at,
        b.billing_at,
        MIN(w.created_at) AS purchase_at
    FROM billing_stage b
    LEFT JOIN website_pageviews w
        ON b.website_session_id = w.website_session_id
        AND w.pageview_url = '/thank-you-for-your-order'
        AND w.created_at > b.billing_at
    GROUP BY
        b.website_session_id,
        b.products_at,
        b.cart_at,
        b.shipping_at,
        b.billing_at
)

SELECT
    COUNT(products_at) AS products_sessions,
    COUNT(cart_at) AS cart_sessions,
    COUNT(shipping_at) AS shipping_sessions,
    COUNT(billing_at) AS billing_sessions,
    COUNT(purchase_at) AS purchase_sessions,
    
    round(
        100.0* count(cart_at)/NULLIF(count(products_at),0),
        2
    ) as product_to_cart_pct,

    round(
        100.0*count(shipping_at)/NULLIF(count(cart_at),0),
        2
    ) as cart_to_shipping_pct,

    round(
        100.0*count(billing_at)/NULLIF(count(shipping_at),0),
        2
    ) as shipping_to_billing_pct,

    round(
        100.0*count(purchase_at)/NULLIF(count(billing_at),0),
        2
    ) as billing_to_purchase_pct
FROM purchase_stage;




#### above code error checking

SELECT
    website_pageview_id,
    website_session_id,
    pageview_url
from website_pageviews
where pageview_url='/products'
limit 10;




SELECT
    count(*) as product_pageviews,
    count(distinct website_session_id) as unique_sessions
from website_pageviews
where pageview_url='/products';




SELECT
    website_session_id,
    count(*) as product_visits
from website_pageviews
where pageview_url='/products'
group by website_session_id
having count(*)>1
limit 10;



#### moving towards power bi
 
select current_database();