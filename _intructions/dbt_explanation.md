DRAFT

Explanation of Our dbt Models

Let me explain the purpose and approach of each model we've created:

Core Models

1. fct_regional_emissions_summary

This model aggregates emissions data by geographic region, allowing you to compare total emissions, per capita emissions, and economic metrics across major world regions. It includes:

Total emissions broken down by greenhouse gas type (CO2, CH4, N2O)
Population and GDP stats per region
Emissions per capita to compare regional efficiency
Distribution of income categories within each region
2. fct_subregional_emissions_summary

This model provides a more granular view by breaking down emissions data to the sub-regional level (e.g., Western Europe, Southeast Asia). It includes:

GHG composition breakdown by percentage
Carbon intensity of economies (emissions per unit of GDP)
Per capita emissions metrics
Dominant GHG composition pattern for each sub-region
Marts Models

3. europe_emissions

This model focuses specifically on European countries, providing:

Detailed emissions profile for each European country
Year-over-year change in emissions (percentage)
Socioeconomic context (income, inequality, education, life expectancy)
Carbon intensity metrics (emissions per capita, emissions per GDP)
4. netherlands_emissions

This model provides a deep dive into a single country (Netherlands):

Year-over-year changes in emissions, population, and GDP
Economic-emissions relationship (decoupling analysis)
Emissions composition (percentage of CO2, CH4, N2O)
Long-term trends in carbon intensity
5. emissions_by_development

This model helps answer "How do emissions vary by economic development level?" by:

Grouping countries by World Bank income categories
Calculating emissions share vs. population share
Computing average emissions per capita by income group
Tracking the percentage of global emissions by development category
6. top_emitting_countries

This model identifies and analyzes the highest emitting countries:

Ranks countries by total emissions, per capita emissions, and carbon intensity
Calculates each country's share of global emissions
Provides emissions-to-population ratio to identify disproportionate emitters
Includes regional context for each country
7. gdp_emissions_correlation

This model explores the relationship between economic growth and emissions:

Calculates GDP growth vs. emissions growth
Identifies decoupling status (absolute, relative, or no decoupling)
Compares countries to regional averages
Provides both short-term (1-year) and long-term (5-year) views
8. emissions_time_series

This model examines how emissions have changed over time:

Year-over-year changes in total and per capita emissions
Long-term comparison to baseline year
Compound annual growth rate (CAGR) of emissions
Classification of long-term emission trends
How to Use These Models for Your Dashboard

To answer your key questions:

How do emissions vary by economic development level?

Use the emissions_by_development model to create:

✅ Bar chart showing total emissions by income category
✅ Line chart tracking emissions per capita across development levels
✅ Comparison of emissions share vs. population share by income group
Which countries have the highest emissions?

Use the top_emitting_countries model to create:

✅ Top 10 emitters by total emissions (bar chart)
✅ Top 10 emitters by per capita emissions (bar chart)
✅ Map visualization of emissions intensity by country
Is there a correlation between GDP and emissions?

Use the gdp_emissions_correlation model to create:

✅ Scatter plot of GDP per capita vs. emissions per capita
Timeline showing countries achieving decoupling
✅ Comparison of carbon intensity by region
How has the emissions profile changed over time?

Use the emissions_time_series model to create:

✅ Line chart showing global emissions trends
Stacked area chart of emissions by gas type over time
✅Comparative timeline of emissions by region


— to do next
This project was performed over an averahe of 30 hours. This is far from enough to make a cohevise end result. 
The focus was to deliver and explore.

The following steps would/should be performed for “real cases”: 

() industry knowledge: what gases have more impact? How to analyse co2 over 20and co2 over 100?
() how to reduce and optimise costs: use of incremental tables in dbt, add variables for processing while tests, optimise queries
() orchestration:
() all in cloud
() local and cloud setup
() better documentation