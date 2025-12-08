% Datapath
load('stimuli_pool.mat','stimuli_pool');
results = zeros(2,10,2,3,3); % Result Matrix

% Initiate Variables
l_all=-12:1:12; % Lambda parameter range
r_all=zeros(length(l_all),2); % Correlation values matrix
l_best=zeros(3,3);
r_best=zeros(3,3);
SUBS_normal = [3 4 5 6 7 8 9 10 13];
SUBS_2_cv = [2 11];
SUBS_12 = [12];
holdouts = [2 4];

% Load Y
Y{1} = stimuli_pool(:,1); % for vowel
Y{2} = stimuli_pool(:,2); % for speaker

% Load Masks
for n_sub=1:length(SUBS_normal)
    sub = SUBS_normal(n_sub);
    for roi=1:10
        masks{sub,roi} = xff('*.msk');
    end
end

for n_sub = 1:length(SUBS_normal)
    sub = SUBS_normal(n_sub);
    for c = 1:2 % 1 = vowel and 2 = speaker
        y = Y{c};
        for roi=1:10
            msk = masks{sub,roi};
            roi = find(msk.Mask);
            filename = sprintf('S%02d_FEATURES_mask_%02d.mat', sub, roi);
            FEATURES = load(filename,'FEATURES');
            FEATURES = FEATURES.FEATURES;
            SIZE = size(FEATURES(1).training);

            for cv=1:3
                training_temp = reshape(FEATURES(cv).training,SIZE(1)*SIZE(2)*SIZE(3),SIZE(4));
                testing_temp = reshape(FEATURES(cv).testing,SIZE(1)*SIZE(2)*SIZE(3),SIZE(4));
                X_train = training_temp(roi,:);
                X_test = testing_temp(roi,:);
                clear training_temp; clear testing_temp;
                % Normalization
                X_mean_train = bsxfun(@minus,X_train,mean(X_train,1));
                X_mean_test = bsxfun(@minus,X_test,mean(X_test,1));
                clear X_train; clear X_test;

                for n_holdout=1:length(holdouts)
                    holdout = holdouts(n_holdout);

                    % Inner Ridge
                    for lamda = 1:length(l_all)
                        for i=1:holdout % 2 = holdout var
                            test = i:holdout:137;
                            train = setdiff(1:137,test);
                            B = ridge(y(train),X_mean_train(:,train)',10^l_all(lamda));

                            % Evaluate
                            yhat = X_mean_train(:,test)'*B;
                            %if crrl==1
                            %r = corr(y(test),yhat);
                            %else
                            r = corr(y(test),yhat,type='Spearman');
                            %end
                            r_all(lamda,i)=r;
                        end
                    end
                    %if kappa==1
                    %option 1:
                    %[~,k_star] = max(mean(r_all,2));
                    %k_best(holdout-1,cv) = k_all(k_star);
                    %else
                    %option 2:
                    [~,l_star] = max(r_all,[],1);
                    l_best(holdout-1,cv) = mean(l_all(l_star));
                    %end

                    % Outer Ridge
                    B = ridge(y,X_mean_train',10^l_best(holdout-1,cv));

                    % Evaluate
                    yhat = X_mean_test'*B;
                    r = corr(y,yhat,type='Spearman');
                    r_best(holdout-1,cv) = r;
                    results(c,roi,1,:,:) = l_best;
                    results(c,roi,2,:,:) = r_best;
                end
            end
            clear FEATURES;
        end
    end
    % Save Result Matrix
    filename = sprintf('S%02d_results.mat', sub);
    save(filename,'results','-v7.3');
    clear results;
end