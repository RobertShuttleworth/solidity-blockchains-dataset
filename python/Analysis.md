# Analysis

## Setup


```python
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scienceplots
import scipy.stats as stats
import seaborn as sns
from scikit_posthocs import posthoc_dunn

# plt.style.use(['science','ieee'])
plt.style.use('ieee')

```


```python
arb_df = pd.read_csv('../arb-contracts-final-results.csv')
eth_df = pd.read_csv('../eth-contracts-final-results.csv')
ftm_df = pd.read_csv('../ftm-contracts-final-results.csv')
opt_df = pd.read_csv('../opt-contracts-final-results.csv')
pol_df = pd.read_csv('../pol-contracts-final-results.csv')

# add column to each df to indicate the blockchain
arb_df['Blockchain'] = 'arb'
eth_df['Blockchain'] = 'eth'
ftm_df['Blockchain'] = 'ftm'
opt_df['Blockchain'] = 'opt'
pol_df['Blockchain'] = 'pol'

blockchains = ['arb', 'eth', 'ftm', 'opt', 'pol']
combined_df = pd.concat([arb_df, eth_df, ftm_df, opt_df, pol_df])
combined_df.to_csv('../combined-results.csv')

```


```python
def create_sub_df(df, keyword):
    new_df = df.filter(regex=f'^({keyword}|Blockchain)')
    new_df.columns = new_df.columns.str.replace(keyword, '')
    return new_df

combined_metrics_df = create_sub_df(combined_df, 'metrics.')
combined_patterns_df = create_sub_df(combined_df, 'patterns.')

# rename Storage Optimization column to Storage Saver
combined_patterns_df = combined_patterns_df.rename(columns={'Storage Optimization': 'Storage Saver'})

```


```python
def get_stats(df):
    df_stats = df.describe()
    df_stats.loc['mode'] = df.mode().iloc[0]
    df_stats = df_stats.rename(index={'50%': 'median'})
    df_stats = df_stats.drop('count')
    return df_stats

combined_stats = get_stats(combined_metrics_df)

```


```python
print('#################################################')
print('overall')
print(combined_stats)

for blockchain, group in combined_metrics_df.groupby('Blockchain'):
    print('#################################################')
    print(blockchain)
    print(get_stats(group))
```

    #################################################
    overall
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                106.482882                 4.910463           0.851916   
    std                 212.832993                10.960443           1.417819   
    min                   1.000000                 0.000000           0.000000   
    25%                  17.000000                 0.000000           0.000000   
    median               53.000000                 1.000000           0.000000   
    75%                 123.000000                 6.000000           1.000000   
    max               13933.000000               470.000000          11.000000   
    mode                 12.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   6.843356             4.205814   
    std                   17.300010             3.127734   
    min                    0.000000             0.000000   
    25%                    0.000000             2.000000   
    median                 2.000000             4.000000   
    75%                    8.000000             6.000000   
    max                 1184.000000           108.000000   
    mode                   0.000000             4.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.674645              2.189069            14.586150   
    std                       0.737741              1.415455            24.720232   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.000000             3.000000   
    median                    0.820000              2.050000             7.000000   
    75%                       1.040000              3.000000            15.000000   
    max                      29.000000             38.000000          1184.000000   
    mode                      0.000000              1.000000             1.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.536200               2.296130              1.866199   
    std                   1.619795               5.583016              5.764575   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               1.000000              2.000000   
    max                  32.000000             106.000000            271.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      13.241612  
    std                       29.956682  
    min                        0.000000  
    25%                        0.000000  
    median                     3.000000  
    75%                       15.000000  
    max                     2892.000000  
    mode                       0.000000  
    #################################################
    arb
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                 95.089264                 5.601378           1.192218   
    std                 175.124638                 9.504110           1.780319   
    min                   1.000000                 0.000000           0.000000   
    25%                  18.000000                 0.000000           0.000000   
    median               50.000000                 2.000000           0.000000   
    75%                 108.000000                 8.000000           2.000000   
    max               10997.000000               373.000000          10.000000   
    mode                 17.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   7.765720             4.484162   
    std                   18.727472             2.945376   
    min                    0.000000             0.000000   
    25%                    0.000000             2.000000   
    median                 3.000000             4.000000   
    75%                    9.000000             6.000000   
    max                 1184.000000           108.000000   
    mode                   0.000000             4.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.651906              2.270774            16.564378   
    std                       0.731563              1.362342            26.457697   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.330000             3.000000   
    median                    0.790000              2.160000             8.000000   
    75%                       1.000000              3.000000            19.000000   
    max                      27.000000             17.000000          1184.000000   
    mode                      0.000000              2.000000             1.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.408319               2.788961              2.264045   
    std                   1.328851               6.112084              6.907590   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               3.000000              2.000000   
    max                  27.000000              85.000000            269.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      14.211865  
    std                       35.668146  
    min                        0.000000  
    25%                        0.000000  
    median                     4.000000  
    75%                       16.000000  
    max                     2892.000000  
    mode                       0.000000  
    #################################################
    eth
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                100.696024                 4.817489           0.632393   
    std                 191.788504                 9.443872           1.127022   
    min                   1.000000                 0.000000           0.000000   
    25%                  17.000000                 0.000000           0.000000   
    median               44.000000                 1.000000           0.000000   
    75%                 111.000000                 6.000000           1.000000   
    max               13244.000000               371.000000          11.000000   
    mode                  5.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   5.434175             4.241696   
    std                   12.948462             3.172024   
    min                    0.000000             0.000000   
    25%                    0.000000             2.000000   
    median                 2.000000             4.000000   
    75%                    7.000000             6.000000   
    max                  385.000000            39.000000   
    mode                   0.000000             4.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.687110              2.219033            12.960027   
    std                       0.722708              1.406319            20.184514   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.000000             3.000000   
    median                    0.890000              2.100000             6.000000   
    75%                       1.080000              3.000000            13.000000   
    max                      13.000000             14.000000           385.000000   
    mode                      0.000000              1.000000             1.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.603584               2.104779              2.143517   
    std                   1.856593               5.140855              7.137326   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               1.000000              1.000000   
    max                  27.000000             106.000000            271.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      11.734234  
    std                       23.321817  
    min                        0.000000  
    25%                        0.000000  
    median                     3.000000  
    75%                       13.000000  
    max                      384.000000  
    mode                       0.000000  
    #################################################
    ftm
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                129.012569                 4.448368           0.565325   
    std                 220.750711                 9.373081           1.019450   
    min                   1.000000                 0.000000           0.000000   
    25%                  17.000000                 0.000000           0.000000   
    median               67.000000                 1.000000           0.000000   
    75%                 152.000000                 6.000000           1.000000   
    max               13933.000000               470.000000           9.000000   
    mode                 10.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   6.559865             4.106899   
    std                   15.057863             3.338562   
    min                    0.000000             0.000000   
    25%                    0.000000             2.000000   
    median                 2.000000             4.000000   
    75%                    8.000000             5.000000   
    max                  385.000000            54.000000   
    mode                   0.000000             4.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.643924              2.156687            13.238643   
    std                       0.723701              1.421859            20.113817   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.000000             3.000000   
    median                    0.730000              2.000000             8.000000   
    75%                       1.040000              3.000000            17.000000   
    max                      29.000000             38.000000           470.000000   
    mode                      0.000000              1.000000             6.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.528597               1.701813              1.322769   
    std                   1.725519               4.613617              3.692247   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               0.000000              1.000000   
    max                  27.000000              71.000000            132.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      12.485621  
    std                       23.920171  
    min                        0.000000  
    25%                        0.000000  
    median                     2.000000  
    75%                       15.000000  
    max                      384.000000  
    mode                       0.000000  
    #################################################
    opt
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                110.796886                 4.749340           0.650580   
    std                 328.033573                18.086118           1.136504   
    min                   1.000000                 0.000000           0.000000   
    25%                  18.000000                 0.000000           0.000000   
    median               55.000000                 1.000000           0.000000   
    75%                 126.000000                 5.000000           1.000000   
    max               13933.000000               460.000000           8.000000   
    mode                 21.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   6.802502             3.953564   
    std                   20.559428             3.126769   
    min                    0.000000             0.000000   
    25%                    0.000000             1.000000   
    median                 2.000000             4.000000   
    75%                    8.000000             5.000000   
    max                  385.000000            65.000000   
    mode                   0.000000             1.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.714576              2.126846            13.793659   
    std                       0.817814              1.508970            29.766062   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.000000             2.000000   
    median                    0.940000              2.000000             7.000000   
    75%                       1.150000              3.000000            13.000000   
    max                      27.000000             18.000000           460.000000   
    mode                      0.000000              1.000000             1.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.640459               1.601358              1.538640   
    std                   1.699429               4.775666              4.346175   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               1.000000              1.000000   
    max                  32.000000              80.000000            168.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      12.528792  
    std                       28.296246  
    min                        0.000000  
    25%                        0.000000  
    median                     3.000000  
    75%                       15.000000  
    max                      384.000000  
    mode                       0.000000  
    #################################################
    pol
            Contract Lines of Code  External Function Count  Inheritance Depth  \
    mean                107.048053                 4.185107           0.788435   
    std                 175.914326                 9.167650           1.186480   
    min                   1.000000                 0.000000           0.000000   
    25%                  17.000000                 0.000000           0.000000   
    median               56.000000                 1.000000           0.000000   
    75%                 119.000000                 6.000000           1.000000   
    max                2986.000000               373.000000           9.000000   
    mode                  9.000000                 0.000000           0.000000   
    
            Internal Function Count  Max Local Variables  \
    mean                   6.415460             3.901338   
    std                   16.770051             3.171772   
    min                    0.000000             0.000000   
    25%                    0.000000             2.000000   
    median                 3.000000             4.000000   
    75%                    8.000000             5.000000   
    max                  384.000000            38.000000   
    mode                   0.000000             4.000000   
    
            Mean Cyclomatic Complexity  Mean Local Variables  Number of Functions  \
    mean                      0.714413              2.078881            13.872402   
    std                       0.710171              1.439465            24.391023   
    min                       0.000000              0.000000             0.000000   
    25%                       0.000000              1.000000             2.000000   
    median                    0.920000              2.000000             7.000000   
    75%                       1.110000              2.710000            14.000000   
    max                      11.000000             14.000000           385.000000   
    mode                      0.000000              1.000000             1.000000   
    
            Private Function Count  Public Function Count  State Variable Count  \
    mean                  0.674623               2.597212              1.657262   
    std                   1.755464               6.148184              4.506337   
    min                   0.000000               0.000000              0.000000   
    25%                   0.000000               0.000000              0.000000   
    median                0.000000               0.000000              0.000000   
    75%                   0.000000               1.000000              1.000000   
    max                  27.000000             106.000000            168.000000   
    mode                  0.000000               0.000000              0.000000   
    
            Total Cyclomatic Complexity  
    mean                      13.804699  
    std                       28.786064  
    min                        0.000000  
    25%                        0.000000  
    median                     4.000000  
    75%                       15.000000  
    max                      384.000000  
    mode                       0.000000  
    

## Metric Boxplots


```python
def create_boxplot(df, column, title, show_outliers=True):
    fig = plt.figure()
    # plt.title(title)

    data = [df[column]]
    labels = ['overall']
    for name, group in df.groupby('Blockchain'):
        data.append(group[column])
        labels.append(name)
    plt.boxplot(data, tick_labels=labels, showfliers=show_outliers)
    plt.ylabel('Lines of Code')
    plt.xlabel('Blockchain')
    plt.show()

for metric in combined_stats.columns:
    create_boxplot(combined_metrics_df, metric, metric)
    create_boxplot(combined_metrics_df, metric, metric + ' - Outliers Removed', False)
```


    
![png](Analysis_files/Analysis_8_0.png)
    



    
![png](Analysis_files/Analysis_8_1.png)
    



    
![png](Analysis_files/Analysis_8_2.png)
    



    
![png](Analysis_files/Analysis_8_3.png)
    



    
![png](Analysis_files/Analysis_8_4.png)
    



    
![png](Analysis_files/Analysis_8_5.png)
    



    
![png](Analysis_files/Analysis_8_6.png)
    



    
![png](Analysis_files/Analysis_8_7.png)
    



    
![png](Analysis_files/Analysis_8_8.png)
    



    
![png](Analysis_files/Analysis_8_9.png)
    



    
![png](Analysis_files/Analysis_8_10.png)
    



    
![png](Analysis_files/Analysis_8_11.png)
    



    
![png](Analysis_files/Analysis_8_12.png)
    



    
![png](Analysis_files/Analysis_8_13.png)
    



    
![png](Analysis_files/Analysis_8_14.png)
    



    
![png](Analysis_files/Analysis_8_15.png)
    



    
![png](Analysis_files/Analysis_8_16.png)
    



    
![png](Analysis_files/Analysis_8_17.png)
    



    
![png](Analysis_files/Analysis_8_18.png)
    



    
![png](Analysis_files/Analysis_8_19.png)
    



    
![png](Analysis_files/Analysis_8_20.png)
    



    
![png](Analysis_files/Analysis_8_21.png)
    



    
![png](Analysis_files/Analysis_8_22.png)
    



    
![png](Analysis_files/Analysis_8_23.png)
    


## Average Metrics


```python
def plot_averages(df, metric, title):
    means = [df[metric].mean()]
    medians = [df[metric].median()]
    modes = [df[metric].mode().iloc[0]]
    labels = ['overall']

    for name, group in df.groupby('Blockchain'):
        means.append(group[metric].mean())
        medians.append(group[metric].median())
        modes.append(group[metric].mode().iloc[0])
        labels.append(name)

    data = {
        'mean': means,
        'median': medians,
        'mode': modes
    }

    label_loc = np.arange(len(labels))
    width = 0.25  # the width of the bars
    multiplier = 0

    fig, ax = plt.subplots(layout='constrained')

    for key, value in data.items():
        offset = width * multiplier
        rects = ax.bar(label_loc + offset, value, width, label=key)
        ax.bar_label(rects, padding=3)
        multiplier += 1

    ax.set_xticks(label_loc + width, labels)

    plt.title(title)
    plt.legend()
    plt.show()

for metric in combined_stats.columns:
    plot_averages(combined_metrics_df, metric, metric)

```


    
![png](Analysis_files/Analysis_10_0.png)
    


## Correlation Analysis

### Setup


```python
metrics = combined_metrics_df.columns.drop('Blockchain')
patterns = combined_patterns_df.columns.drop('Blockchain')
# drop patterns removed from the final analysis
patterns = patterns.drop('Multi Return')
patterns = patterns.drop('State Machine')
patterns = patterns.drop('Permissioned')
patterns = patterns.drop('Permissionless')

```

### Spearman


```python
def spearman_corr(blockchain=None):
    """
    Computes Spearman correlation between software metrics and micropatterns.
    If a blockchain is specified, it computes the correlation for that blockchain only.
    """
    corr_matrix = pd.DataFrame(index=metrics, columns=patterns)

    title = "Spearman Correlation Between Software Metrics and Micro-patterns"

    if blockchain:
        blockchain_metrics_df = combined_metrics_df[combined_metrics_df['Blockchain'] == blockchain]
        blockchain_patterns_df = combined_patterns_df[combined_patterns_df['Blockchain'] == blockchain]
        title = f"{title} ({blockchain})"
        print(title)
    else:
        blockchain_metrics_df = combined_metrics_df
        blockchain_patterns_df = combined_patterns_df
        title = f"{title} (overall)"
        print(title)

    for pattern in patterns:
        for metric in metrics:
            r, p = stats.spearmanr(blockchain_metrics_df[metric], blockchain_patterns_df[pattern])
            corr_matrix.loc[metric, pattern] = r

    corr_matrix = corr_matrix.astype(float)
    print(corr_matrix)

    # Plot correlation matrix
    plt.figure(figsize=(10, 6))
    sns.heatmap(corr_matrix, annot=True, fmt=".2f", cmap="coolwarm", center=0, linewidths=0.5)
    plt.title(title)
    plt.xlabel("Micro-patterns")
    plt.ylabel("Software Metrics")
    plt.show()

# Compute Spearman correlation for overall and per blockchain
spearman_corr()
for blockchain in blockchains:
    spearman_corr(blockchain)

```

### Kruskal-Wallis Test


```python
def is_normal(data):
    _, p = stats.normaltest(data, nan_policy='omit')
    return p > 0.05  # p > 0.05 means data is approximately normal

def kruskal_wallis():
    significant_metrics = []
    for metric in metrics:
        groups = [group[metric] for name, group in combined_metrics_df.groupby('Blockchain')]
        h_stat, p_val = stats.kruskal(*groups)
        print(f"{metric}: Kruskal-Wallis H = {h_stat:.2f}, p = {p_val:.4e} (Non-parametric)")
        if p_val < 0.05:
            significant_metrics.append(metric)
    return significant_metrics

kw_metrics = kruskal_wallis()

```

### Dunn's Test


```python
def dunns_test():
    dunn_results = {}
    for metric in kw_metrics:
        posthoc_matrix = posthoc_dunn(combined_metrics_df, val_col=metric, group_col='Blockchain', p_adjust='bonferroni')
        dunn_results[metric] = posthoc_matrix

    # Display Dunn’s test results
    for metric, result in dunn_results.items():
        plt.figure(figsize=(8, 6))
        sns.heatmap(result, annot=True, fmt=".2f", cmap="coolwarm", vmin=0, vmax=1, linewidths=0.5,
                    cbar_kws={'label': 'p-value'})

        plt.title(f"Dunn’s Test for {metric}")
        plt.xlabel("Blockchain")
        plt.ylabel("Blockchain")
        plt.xticks(rotation=45, ha="right")
        plt.yticks(rotation=0)

        plt.show()

dunns_test()
```
